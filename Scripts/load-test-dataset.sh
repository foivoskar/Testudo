#!/bin/bash
set -euo pipefail

APP_DIR="$HOME/Library/Application Support/DReport"
DATA="$APP_DIR/DReportData.json"
BACKUP_DIR="$APP_DIR/TestDataBackups"
MANIFEST="$APP_DIR/TestDatasetManifest.json"

mkdir -p "$APP_DIR"
mkdir -p "$BACKUP_DIR"

if [ ! -f "$DATA" ]; then
    echo "ERROR: DReportData.json does not exist."
    echo "Open DReport and create the first Administrator first."
    exit 1
fi

pkill -x DReport 2>/dev/null || true
sleep 1

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_DIR/DReportData-before-test-$STAMP.json"

cp "$DATA" "$BACKUP"

echo
echo "=========================================="
echo "  DREPORT TEST DATASET"
echo "=========================================="
echo
echo "Backup:"
echo "$BACKUP"
echo

python3 <<'PY'
from pathlib import Path
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import base64
import hashlib
import json
import os
import uuid

app_dir = Path.home() / "Library/Application Support/DReport"
data_path = app_dir / "DReportData.json"
manifest_path = app_dir / "TestDatasetManifest.json"

data = json.loads(data_path.read_text())

for key in [
    "themes",
    "workItems",
    "entities",
    "memberships",
    "personProfiles",
    "workEntityRelationships",
    "historyEvents",
    "users",
]:
    data.setdefault(key, [])

old_manifest = {}

if manifest_path.exists():
    try:
        old_manifest = json.loads(
            manifest_path.read_text()
        )
    except Exception:
        old_manifest = {}

old_ids = {
    key: set(old_manifest.get(key, []))
    for key in [
        "themes",
        "workItems",
        "entities",
        "memberships",
        "personProfiles",
        "workEntityRelationships",
        "users",
    ]
}

old_entity_ids = old_ids["entities"]
old_work_ids = old_ids["workItems"]

for key in [
    "themes",
    "workItems",
    "entities",
    "memberships",
    "personProfiles",
    "workEntityRelationships",
    "users",
]:
    if old_ids[key]:
        data[key] = [
            obj
            for obj in data.get(key, [])
            if obj.get("id") not in old_ids[key]
        ]

data["memberships"] = [
    obj
    for obj in data["memberships"]
    if obj.get("memberEntityID") not in old_entity_ids
    and obj.get("containerEntityID") not in old_entity_ids
]

data["workEntityRelationships"] = [
    obj
    for obj in data["workEntityRelationships"]
    if obj.get("entityID") not in old_entity_ids
    and obj.get("workItemID") not in old_work_ids
]

data["historyEvents"] = [
    obj
    for obj in data["historyEvents"]
    if obj.get("workItemID") not in old_work_ids
]

def uid():
    return str(uuid.uuid4())

def find_date_sample():
    for collection in [
        "users",
        "themes",
        "workItems",
        "entities",
        "memberships",
        "personProfiles",
    ]:
        for obj in data.get(collection, []):
            for key, value in obj.items():
                if (
                    key.endswith("At")
                    and value is not None
                ):
                    return value
    return 0.0

date_sample = find_date_sample()

swift_reference = datetime(
    2001,
    1,
    1,
    tzinfo=timezone.utc,
)

def encode_date(dt):
    dt = dt.astimezone(timezone.utc)

    if isinstance(
        date_sample,
        (int, float)
    ):
        return (
            dt - swift_reference
        ).total_seconds()

    if isinstance(
        date_sample,
        str
    ):
        return (
            dt.isoformat(
                timespec="milliseconds"
            )
            .replace(
                "+00:00",
                "Z"
            )
        )

    return (
        dt - swift_reference
    ).total_seconds()

now = datetime.now(
    timezone.utc
)

def when(
    days=0,
    hours=0,
    minutes=0
):
    return encode_date(
        now
        + timedelta(
            days=days,
            hours=hours,
            minutes=minutes,
        )
    )

manifest = {
    "themes": [],
    "workItems": [],
    "entities": [],
    "memberships": [],
    "personProfiles": [],
    "workEntityRelationships": [],
    "users": [],
}

theme_template = (
    deepcopy(data["themes"][0])
    if data["themes"]
    else {}
)

work_template = (
    deepcopy(data["workItems"][0])
    if data["workItems"]
    else {}
)

entity_template = (
    deepcopy(data["entities"][0])
    if data["entities"]
    else {}
)

membership_template = (
    deepcopy(data["memberships"][0])
    if data["memberships"]
    else {}
)

relationship_template = (
    deepcopy(
        data["workEntityRelationships"][0]
    )
    if data["workEntityRelationships"]
    else {}
)

user_template = (
    deepcopy(data["users"][0])
    if data["users"]
    else {}
)

def append_tracked(
    collection,
    obj
):
    data[collection].append(obj)

    if "id" in obj:
        manifest[collection].append(
            obj["id"]
        )

    return obj["id"]

def make_theme(
    name,
    notes="",
    parent=None,
    age_days=60,
):
    obj = deepcopy(theme_template)

    obj["id"] = uid()
    obj["name"] = name
    obj["notes"] = notes
    obj["createdAt"] = when(
        -age_days
    )
    obj["updatedAt"] = when(-1)

    if parent:
        obj["parentThemeID"] = parent
    else:
        obj.pop(
            "parentThemeID",
            None
        )

    append_tracked(
        "themes",
        obj
    )

    return obj["id"]

def make_entity(
    kind,
    name,
    notes="",
    age_days=90,
):
    obj = deepcopy(entity_template)

    obj["id"] = uid()
    obj["kind"] = kind
    obj["name"] = name
    obj["notes"] = notes
    obj["createdAt"] = when(
        -age_days
    )
    obj["updatedAt"] = when(-2)

    append_tracked(
        "entities",
        obj
    )

    return obj["id"]

def make_profile(
    entity_id,
    first_name,
    last_name,
    **kwargs
):
    obj = {
        "id": uid(),
        "entityID": entity_id,
        "firstName": first_name,
        "middleName": kwargs.get(
            "middleName",
            ""
        ),
        "lastName": last_name,
        "preferredName": kwargs.get(
            "preferredName",
            ""
        ),
        "jobTitle": kwargs.get(
            "jobTitle",
            ""
        ),
        "professionalEmail":
            kwargs.get(
                "professionalEmail",
                ""
            ),
        "secondaryProfessionalEmail":
            kwargs.get(
                "secondaryProfessionalEmail",
                ""
            ),
        "professionalPhone":
            kwargs.get(
                "professionalPhone",
                ""
            ),
        "office": kwargs.get(
            "office",
            ""
        ),
        "employeeID": kwargs.get(
            "employeeID",
            ""
        ),
        "website": kwargs.get(
            "website",
            ""
        ),
        "orcid": kwargs.get(
            "orcid",
            ""
        ),
        "linkedIn": kwargs.get(
            "linkedIn",
            ""
        ),
        "github": kwargs.get(
            "github",
            ""
        ),
        "professionalFields":
            kwargs.get(
                "professionalFields",
                ""
            ),
        "responsibilities":
            kwargs.get(
                "responsibilities",
                ""
            ),
        "notes": kwargs.get(
            "notes",
            ""
        ),
        "avatarData": None,
        "academicTitle":
            kwargs.get(
                "academicTitle"
            ),
        "secondaryPhone":
            kwargs.get(
                "secondaryPhone"
            ),
        "professionalAddress":
            kwargs.get(
                "professionalAddress"
            ),
        "city": kwargs.get(
            "city"
        ),
        "postalCode":
            kwargs.get(
                "postalCode"
            ),
        "country": kwargs.get(
            "country"
        ),
        "researcherID":
            kwargs.get(
                "researcherID"
            ),
        "scopusAuthorID":
            kwargs.get(
                "scopusAuthorID"
            ),
        "googleScholarURL":
            kwargs.get(
                "googleScholarURL"
            ),
        "preferredLanguage":
            kwargs.get(
                "preferredLanguage"
            ),
        "timeZone":
            kwargs.get(
                "timeZone"
            ),
        "assistantContact":
            kwargs.get(
                "assistantContact"
            ),
        "tags": kwargs.get(
            "tags"
        ),
        "createdAt": when(-90),
        "updatedAt": when(-1),
    }

    append_tracked(
        "personProfiles",
        obj
    )

    return obj["id"]

def make_membership(
    member,
    container,
    primary=False,
):
    obj = deepcopy(
        membership_template
    )

    obj["id"] = uid()
    obj["memberEntityID"] = member
    obj["containerEntityID"] = (
        container
    )
    obj["isPrimary"] = primary
    obj["createdAt"] = when(-45)

    append_tracked(
        "memberships",
        obj
    )

    return obj["id"]

def make_work(
    kind,
    theme,
    title,
    body="",
    parent=None,
    status=None,
    created_days=-5,
    updated_days=0,
    deadline_days=None,
    scheduled_days=None,
    scheduled_hours=0,
    started_days=None,
    completed_days=None,
    logged_days=None,
    creator=None,
):
    obj = deepcopy(work_template)

    obj["id"] = uid()
    obj["themeID"] = theme
    obj["kind"] = kind
    obj["title"] = title
    obj["body"] = body
    obj["createdAt"] = when(
        created_days
    )
    obj["updatedAt"] = when(
        updated_days
    )

    if parent:
        obj["parentWorkItemID"] = (
            parent
        )
    else:
        obj.pop(
            "parentWorkItemID",
            None
        )

    if status is not None:
        obj["status"] = status
    else:
        obj.pop(
            "status",
            None
        )

    if deadline_days is not None:
        obj["deadlineAt"] = when(
            deadline_days,
            3
        )
    else:
        obj.pop(
            "deadlineAt",
            None
        )

    if scheduled_days is not None:
        obj["scheduledAt"] = when(
            scheduled_days,
            scheduled_hours
        )
    else:
        obj.pop(
            "scheduledAt",
            None
        )

    if started_days is not None:
        obj["startedAt"] = when(
            started_days
        )
    else:
        obj.pop(
            "startedAt",
            None
        )

    if completed_days is not None:
        obj["completedAt"] = when(
            completed_days
        )
    else:
        obj.pop(
            "completedAt",
            None
        )

    if logged_days is not None:
        obj["loggedAt"] = when(
            logged_days
        )
    else:
        obj.pop(
            "loggedAt",
            None
        )

    if creator:
        obj["createdByUserID"] = (
            creator
        )
        obj["updatedByUserID"] = (
            creator
        )
    else:
        obj.pop(
            "createdByUserID",
            None
        )
        obj.pop(
            "updatedByUserID",
            None
        )

    append_tracked(
        "workItems",
        obj
    )

    return obj["id"]

def make_relation(
    work,
    entity,
    role,
    inherited=False,
):
    obj = deepcopy(
        relationship_template
    )

    obj["id"] = uid()
    obj["workItemID"] = work
    obj["entityID"] = entity
    obj["role"] = role
    obj["inheritedByChildren"] = (
        inherited
    )
    obj["createdAt"] = when(-4)

    append_tracked(
        "workEntityRelationships",
        obj
    )

    return obj["id"]

def make_password(
    password,
    iterations=120000,
):
    salt = os.urandom(16)

    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        iterations,
        dklen=32,
    )

    return (
        base64.b64encode(
            salt
        ).decode(),
        base64.b64encode(
            digest
        ).decode(),
        iterations,
    )

def unique_username(base):
    existing = {
        u.get(
            "username",
            ""
        ).lower()
        for u in data["users"]
    }

    if base.lower() not in existing:
        return base

    index = 2

    while (
        f"{base}.{index}".lower()
        in existing
    ):
        index += 1

    return f"{base}.{index}"

def make_user(
    person_id,
    first_name,
    last_name,
    username,
    password,
    active=True,
    role="member",
    last_login_days=None,
):
    obj = deepcopy(user_template)

    salt, digest, iterations = (
        make_password(password)
    )

    obj["id"] = uid()
    obj["personEntityID"] = person_id
    obj["username"] = unique_username(
        username
    )
    obj["firstName"] = first_name
    obj["lastName"] = last_name
    obj["role"] = role

    obj["passwordSaltBase64"] = salt
    obj["passwordHashBase64"] = (
        digest
    )
    obj["passwordIterations"] = (
        iterations
    )

    obj["avatarData"] = None
    obj["isActive"] = active
    obj["createdAt"] = when(-25)
    obj["updatedAt"] = when(-1)

    if last_login_days is not None:
        obj["lastLoginAt"] = when(
            last_login_days
        )
    else:
        obj["lastLoginAt"] = None

    append_tracked(
        "users",
        obj
    )

    return obj

existing_admin = next(
    (
        user
        for user in data["users"]
        if user.get("role")
            == "administrator"
        and user.get(
            "isActive",
            True
        )
    ),
    None,
)

existing_user = (
    existing_admin
    or (
        data["users"][0]
        if data["users"]
        else None
    )
)

actor_id = (
    existing_user.get("id")
    if existing_user
    else None
)

research = make_theme(
    "Research",
    "Scientific research projects and analyses.",
    age_days=180,
)

mars = make_theme(
    "Mars Seismology",
    "Martian seismicity, impacts, scattering and attenuation.",
    parent=research,
    age_days=160,
)

impacts = make_theme(
    "Impact Events",
    "Meteor impacts and atmospheric / seismic coupling.",
    parent=mars,
    age_days=150,
)

earth_structure = make_theme(
    "Earth Structure",
    "Mantle structure, anisotropy and seismic imaging.",
    parent=research,
    age_days=140,
)

infrastructure = make_theme(
    "Infrastructure",
    "Scientific computing, storage and technical infrastructure.",
    age_days=130,
)

storage = make_theme(
    "Storage Systems",
    "Distributed storage, backup and long-term archiving.",
    parent=infrastructure,
    age_days=120,
)

software = make_theme(
    "Software",
    "Internal tools and scientific software.",
    age_days=100,
)

dreport_theme = make_theme(
    "DReport",
    "Development and testing of the DReport application.",
    parent=software,
    age_days=30,
)

seminars = make_theme(
    "Seminars",
    "Speaker invitations, scheduling and seminar organization.",
    age_days=90,
)

administration = make_theme(
    "Administration",
    "Administrative and organizational work.",
    age_days=80,
)

outreach = make_theme(
    "Outreach",
    "Workshops, public engagement and open-science activities.",
    age_days=70,
)

northstar = make_entity(
    "organization",
    "Northstar University",
    "Demo university used by the DReport test dataset.",
)

faculty = make_entity(
    "organization",
    "Faculty of Science",
    "Faculty within Northstar University.",
)

earth_dept = make_entity(
    "organization",
    "Department of Earth & Planetary Sciences",
    "Research and teaching department.",
)

egi = make_entity(
    "organization",
    "European Geoscience Institute",
    "International geoscience research institute.",
)

alpine = make_entity(
    "organization",
    "Alpine Observatory",
    "Regional geophysical observatory.",
)

open_science = make_entity(
    "organization",
    "Open Science Foundation",
    "Non-profit organization supporting open scientific practice.",
)

geodata = make_entity(
    "organization",
    "GeoData Services",
    "Scientific data and infrastructure organization.",
)

planetary_lab = make_entity(
    "group",
    "Planetary Seismology Lab",
    "Research group studying planetary seismic signals.",
)

anisotropy_group = make_entity(
    "group",
    "Imaging & Anisotropy Group",
    "Earth structure and anisotropy research group.",
)

data_team = make_entity(
    "group",
    "Data Infrastructure Team",
    "Storage, networking and compute infrastructure.",
)

seminar_committee = make_entity(
    "group",
    "Seminar Committee",
    "Organizes the departmental seminar series.",
)

open_working_group = make_entity(
    "group",
    "Open Science Working Group",
    "Cross-institutional open-science working group.",
)

mars_collab = make_entity(
    "group",
    "Mars Impacts Collaboration",
    "International collaboration on Martian impacts.",
)

make_membership(
    faculty,
    northstar,
    True
)

make_membership(
    earth_dept,
    faculty,
    True
)

make_membership(
    planetary_lab,
    earth_dept,
    True
)

make_membership(
    anisotropy_group,
    earth_dept,
    True
)

make_membership(
    seminar_committee,
    earth_dept,
    True
)

make_membership(
    data_team,
    geodata,
    True
)

make_membership(
    mars_collab,
    egi,
    True
)

people = {}

def add_person(
    key,
    first,
    last,
    **profile
):
    display_name = (
        f"{first} {last}"
    ).strip()

    entity_id = make_entity(
        "person",
        display_name,
        "DReport demo person.",
        age_days=60,
    )

    make_profile(
        entity_id,
        first,
        last,
        **profile
    )

    people[key] = entity_id

    return entity_id

elena = add_person(
    "elena",
    "Elena",
    "Rossi",
    academicTitle="Dr.",
    jobTitle="Senior Seismologist",
    professionalEmail="elena.rossi@example.test",
    secondaryProfessionalEmail="e.rossi@example.test",
    professionalPhone="+33 1 84 00 11 21",
    secondaryPhone="+39 02 555 0112",
    office="B-412",
    employeeID="NSU-ES-1042",
    website="https://example.test/elena-rossi",
    orcid="0000-0002-1825-0097",
    linkedIn="elena-rossi-demo",
    github="erossi-demo",
    professionalFields="Planetary seismology; impact seismology; waveform analysis",
    responsibilities="Mars impact catalogue; graduate supervision; instrument working group",
    professionalAddress="14 Science Avenue",
    city="Paris",
    postalCode="75005",
    country="France",
    researcherID="AAB-1234-2026",
    scopusAuthorID="57200000001",
    googleScholarURL="https://example.test/scholar/elena",
    preferredLanguage="Italian",
    timeZone="Europe/Paris",
    tags="Mars, Seismology, Impacts",
    notes="Prefers meetings before 16:00. Visiting the observatory twice per year.",
)

martin = add_person(
    "martin",
    "Martin",
    "Weber",
    academicTitle="Prof.",
    jobTitle="Professor of Geophysics",
    professionalEmail="martin.weber@example.test",
    professionalPhone="+49 30 555 0101",
    office="4.17",
    website="https://example.test/martin-weber",
    orcid="0000-0001-5109-3700",
    professionalFields="Mantle anisotropy; seismic tomography; subduction",
    responsibilities="Research group lead; doctoral supervision",
    city="Berlin",
    country="Germany",
    preferredLanguage="German",
    timeZone="Europe/Berlin",
    tags="Mantle, Anisotropy",
)

amina = add_person(
    "amina",
    "Amina",
    "Benali",
    jobTitle="Research Software Engineer",
    professionalEmail="amina.benali@example.test",
    professionalPhone="+33 1 84 00 11 35",
    office="C-208",
    github="abenali-demo",
    linkedIn="amina-benali-demo",
    professionalFields="Scientific software; reproducible workflows; Python; Swift",
    responsibilities="Research software architecture; code review; CI",
    city="Paris",
    country="France",
    preferredLanguage="French",
    timeZone="Europe/Paris",
    tags="Software, Reproducibility",
)

lucas = add_person(
    "lucas",
    "Lucas",
    "Martin",
    jobTitle="Data Infrastructure Engineer",
    professionalEmail="lucas.martin@example.test",
    professionalPhone="+33 1 84 00 12 05",
    office="Server Room 2 / Office D-113",
    employeeID="GDS-441",
    github="lmartin-infra-demo",
    professionalFields="Ceph; Linux; networking; storage systems",
    responsibilities="Storage operations; backups; cluster maintenance",
    professionalAddress="8 Data Centre Road",
    city="Saint-Denis",
    postalCode="93200",
    country="France",
    preferredLanguage="French",
    timeZone="Europe/Paris",
    tags="Ceph, Infrastructure, Storage",
)

sofia = add_person(
    "sofia",
    "Sofia",
    "Papadopoulou",
    academicTitle="Dr.",
    jobTitle="Postdoctoral Researcher",
    professionalEmail="sofia.papadopoulou@example.test",
    office="B-405",
    orcid="0000-0003-1415-9265",
    professionalFields="Scattering attenuation; crustal structure; inverse problems",
    responsibilities="Waveform processing; paper preparation",
    city="Paris",
    country="France",
    preferredLanguage="Greek",
    tags="Scattering, Mars",
)

kenji = add_person(
    "kenji",
    "Kenji",
    "Sato",
    academicTitle="Dr.",
    jobTitle="Visiting Scientist",
    professionalEmail="kenji.sato@example.test",
    website="https://example.test/kenji-sato",
    professionalFields="Impact physics; numerical modelling",
    city="Tokyo",
    country="Japan",
    preferredLanguage="Japanese",
    timeZone="Asia/Tokyo",
)

maya = add_person(
    "maya",
    "Maya",
    "Thompson",
    jobTitle="Seminar Coordinator",
    professionalEmail="maya.thompson@example.test",
    professionalPhone="+44 20 5555 0150",
    office="Admin 2.04",
    responsibilities="Speaker logistics; seminar calendar; room coordination",
    city="London",
    country="United Kingdom",
    preferredLanguage="English",
    timeZone="Europe/London",
    tags="Seminars, Coordination",
)

daniel = add_person(
    "daniel",
    "Daniel",
    "Moreau",
    jobTitle="Finance & Administration Officer",
    professionalEmail="daniel.moreau@example.test",
    employeeID="NSU-ADM-551",
    office="A-118",
    responsibilities="Expenses; purchase orders; travel administration",
    city="Paris",
    country="France",
    preferredLanguage="French",
)

ana = add_person(
    "ana",
    "Ana",
    "Torres",
    jobTitle="PhD Candidate",
    professionalEmail="ana.torres@example.test",
    office="B-421",
    github="atorres-demo",
    professionalFields="Lower mantle structure; receiver functions",
    responsibilities="Doctoral research",
    city="Paris",
    country="France",
    preferredLanguage="Spanish",
    tags="PhD, Mantle",
)

omar = add_person(
    "omar",
    "Omar",
    "Haddad",
    academicTitle="Dr.",
    jobTitle="External Collaborator",
    professionalEmail="omar.haddad@example.test",
    professionalFields="Open science; scientific data stewardship",
    website="https://example.test/omar-haddad",
    city="Algiers",
    country="Algeria",
    preferredLanguage="French",
    timeZone="Africa/Algiers",
    tags="Open Science, Data",
)

nora = add_person(
    "nora",
    "Nora",
    "Lee",
    professionalEmail="nora.lee@example.test",
    notes="Intentionally sparse profile for testing incomplete Person records.",
)

make_membership(
    elena,
    planetary_lab,
    True
)

make_membership(
    elena,
    mars_collab,
    False
)

make_membership(
    martin,
    anisotropy_group,
    True
)

make_membership(
    martin,
    earth_dept,
    False
)

make_membership(
    amina,
    planetary_lab,
    True
)

make_membership(
    amina,
    open_working_group,
    False
)

make_membership(
    lucas,
    data_team,
    True
)

make_membership(
    sofia,
    planetary_lab,
    True
)

make_membership(
    sofia,
    mars_collab,
    False
)

make_membership(
    kenji,
    mars_collab,
    True
)

make_membership(
    maya,
    seminar_committee,
    True
)

make_membership(
    daniel,
    earth_dept,
    True
)

make_membership(
    ana,
    anisotropy_group,
    True
)

make_membership(
    omar,
    open_working_group,
    True
)

test_password = "DReportTest!2026"

elena_user = make_user(
    elena,
    "Elena",
    "Rossi",
    "elena.rossi",
    test_password,
    active=True,
    role="member",
    last_login_days=-1,
)

lucas_user = make_user(
    lucas,
    "Lucas",
    "Martin",
    "lucas.martin",
    test_password,
    active=False,
    role="member",
)

if actor_id is None:
    demo_admin = add_person(
        "demo_admin",
        "Demo",
        "Administrator",
        jobTitle="DReport Administrator",
        professionalEmail="admin@example.test",
        notes="Automatically created because no existing Administrator was found.",
    )

    admin_user = make_user(
        demo_admin,
        "Demo",
        "Administrator",
        "demo.admin",
        test_password,
        active=True,
        role="administrator",
        last_login_days=0,
    )

    actor_id = admin_user["id"]

prepare_seminar = make_work(
    "task",
    seminars,
    "Prepare October seminar",
    "Coordinate speaker, room, announcement and technical setup.",
    status="inProgress",
    created_days=-12,
    deadline_days=5,
    started_days=-10,
    creator=actor_id,
)

confirm_speaker = make_work(
    "task",
    seminars,
    "Confirm speaker",
    "Obtain final confirmation and talk title.",
    parent=prepare_seminar,
    status="completed",
    created_days=-11,
    completed_days=-8,
    creator=actor_id,
)

book_room = make_work(
    "task",
    seminars,
    "Book seminar room",
    "Reserve the main seminar room and confirm hybrid equipment.",
    parent=prepare_seminar,
    status="todo",
    created_days=-8,
    deadline_days=2,
    creator=actor_id,
)

announcement = make_work(
    "task",
    seminars,
    "Prepare seminar announcement",
    "Draft title, abstract, biography and distribution email.",
    parent=prepare_seminar,
    status="todo",
    created_days=-6,
    deadline_days=3,
    creator=actor_id,
)

seminar_note = make_work(
    "note",
    seminars,
    "Speaker travel constraints",
    "Speaker arrives by train at 12:10 and prefers vegetarian lunch.",
    parent=prepare_seminar,
    created_days=-4,
    logged_days=-4,
    creator=actor_id,
)

seminar_call = make_work(
    "activity",
    seminars,
    "Planning call with speaker",
    "Discussed talk duration, audience and hybrid connection.",
    parent=prepare_seminar,
    created_days=-1,
    logged_days=-1,
    creator=actor_id,
)

seminar_event = make_work(
    "activity",
    seminars,
    "October seminar",
    "Demo future event. This is currently stored as Activity and will migrate to Event.",
    parent=prepare_seminar,
    created_days=-5,
    scheduled_days=12,
    scheduled_hours=1,
    creator=actor_id,
)

manuscript = make_work(
    "task",
    mars,
    "Revise manuscript after peer review",
    "Address reviewer comments and prepare revised manuscript.",
    status="inProgress",
    created_days=-21,
    deadline_days=-3,
    started_days=-18,
    creator=actor_id,
)

rerun_inversion = make_work(
    "task",
    mars,
    "Re-run attenuation inversion",
    "Repeat inversion with revised uncertainty bounds.",
    parent=manuscript,
    status="completed",
    created_days=-17,
    completed_days=-6,
    creator=actor_id,
)

rewrite_methods = make_work(
    "task",
    mars,
    "Rewrite methods section",
    "Clarify scattering and intrinsic attenuation methodology.",
    parent=manuscript,
    status="inProgress",
    created_days=-10,
    deadline_days=1,
    started_days=-7,
    creator=actor_id,
)

reviewer_note = make_work(
    "note",
    mars,
    "Reviewer 2 interpretation",
    "Reviewer appears to interpret Q as purely intrinsic. Explicitly separate scattering and intrinsic terms in the response.",
    parent=manuscript,
    created_days=-7,
    logged_days=-7,
    creator=actor_id,
)

coauthor_meeting = make_work(
    "activity",
    mars,
    "Co-author meeting",
    "Agreed on new figure order and additional sensitivity test.",
    parent=manuscript,
    created_days=0,
    logged_days=0,
    creator=actor_id,
)

ceph = make_work(
    "task",
    storage,
    "Ceph cold-storage pilot",
    "Prepare a test deployment for long-term scientific data storage.",
    status="inProgress",
    created_days=-16,
    deadline_days=14,
    started_days=-14,
    creator=actor_id,
)

add_osds = make_work(
    "task",
    storage,
    "Add OSD nodes",
    "Add test disks and verify orchestrator inventory.",
    parent=ceph,
    status="inProgress",
    created_days=-12,
    deadline_days=4,
    started_days=-9,
    creator=actor_id,
)

recovery_test = make_work(
    "task",
    storage,
    "Test recovery after OSD loss",
    "Simulate one OSD failure and document recovery behaviour.",
    parent=ceph,
    status="todo",
    created_days=-9,
    deadline_days=9,
    creator=actor_id,
)

ceph_docs = make_work(
    "task",
    storage,
    "Draft operational notes",
    "Document host addition, OSD provisioning and CRUSH decisions.",
    parent=ceph,
    status="todo",
    created_days=-8,
    creator=actor_id,
)

hardware_note = make_work(
    "note",
    storage,
    "Test hardware inventory",
    "One node has a mixed disk configuration. Verify rotational flag before automated OSD placement.",
    parent=ceph,
    created_days=-3,
    logged_days=-3,
    creator=actor_id,
)

dreport = make_work(
    "task",
    dreport_theme,
    "DReport v0.1",
    "Build a local-first daily work reporting and task management application.",
    status="inProgress",
    created_days=-20,
    deadline_days=21,
    started_days=-20,
    creator=actor_id,
)

people_users = make_work(
    "task",
    dreport_theme,
    "Implement People and Users",
    "Separate domain People from authenticated Users and support account linking.",
    parent=dreport,
    status="completed",
    created_days=-5,
    completed_days=0,
    creator=actor_id,
)

today_dashboard = make_work(
    "task",
    dreport_theme,
    "Implement Today dashboard",
    "Show what needs attention now: deadlines, reminders, events and ongoing work.",
    parent=dreport,
    status="todo",
    created_days=-1,
    deadline_days=3,
    creator=actor_id,
)

events_reminders = make_work(
    "task",
    dreport_theme,
    "Implement Events and Reminders",
    "Replace Activity with Event and add reminder dates to Notes and Events.",
    parent=dreport,
    status="todo",
    created_days=0,
    deadline_days=5,
    creator=actor_id,
)

ui_note = make_work(
    "note",
    dreport_theme,
    "Sidebar visual direction",
    "Keep the sidebar visually close to macOS Mail: compact, quiet, aligned and without unnecessary separator lines.",
    parent=dreport,
    created_days=0,
    logged_days=0,
    creator=actor_id,
)

design_review = make_work(
    "activity",
    dreport_theme,
    "DReport design review",
    "Reviewed People/User model, profile editing and account administration.",
    parent=dreport,
    created_days=0,
    logged_days=0,
    creator=actor_id,
)

test_dataset = make_work(
    "task",
    dreport_theme,
    "Prepare comprehensive test dataset",
    "Populate all major parts of DReport with realistic demo data.",
    parent=dreport,
    status="completed",
    created_days=0,
    completed_days=0,
    creator=actor_id,
)

expenses = make_work(
    "task",
    administration,
    "Submit travel reimbursement",
    "Submit train, hotel and meal receipts.",
    status="completed",
    created_days=-9,
    completed_days=-1,
    deadline_days=-2,
    creator=actor_id,
)

receipt_note = make_work(
    "note",
    administration,
    "Missing taxi receipt",
    "Taxi receipt is stored in the travel folder as a PDF scan.",
    parent=expenses,
    created_days=-5,
    logged_days=-5,
    creator=actor_id,
)

leave_request = make_work(
    "task",
    administration,
    "Submit annual leave request",
    "Prepare dates and submit leave request.",
    status="todo",
    created_days=-2,
    deadline_days=30,
    creator=actor_id,
)

workshop = make_work(
    "task",
    outreach,
    "Open-science workshop proposal",
    "Draft a half-day workshop on reproducible geoscience workflows.",
    status="todo",
    created_days=-14,
    creator=actor_id,
)

workshop_note = make_work(
    "note",
    outreach,
    "Workshop ideas",
    "Possible modules: reproducible notebooks, metadata, version control and data citation.",
    parent=workshop,
    created_days=-8,
    logged_days=-8,
    creator=actor_id,
)

workshop_call = make_work(
    "activity",
    outreach,
    "Workshop planning call",
    "Future planning call with external collaborator.",
    parent=workshop,
    created_days=-1,
    scheduled_days=7,
    scheduled_hours=2,
    creator=actor_id,
)

archive = make_work(
    "task",
    storage,
    "Build long-term waveform archive",
    "Long-running task without a deadline.",
    status="inProgress",
    created_days=-45,
    started_days=-40,
    creator=actor_id,
)

paper_reading = make_work(
    "task",
    earth_structure,
    "Read paper on lower-mantle anisotropy",
    "Read and annotate the new tomography / anisotropy paper.",
    status="todo",
    created_days=-3,
    deadline_days=0,
    creator=actor_id,
)

paper_note = make_work(
    "note",
    earth_structure,
    "Paper reading note",
    "Compare the authors' parameterisation with the existing global model.",
    parent=paper_reading,
    created_days=-2,
    logged_days=-2,
    creator=actor_id,
)

team_meeting = make_work(
    "activity",
    research,
    "Weekly research team meeting",
    "Discussed manuscript status, incoming visitor and storage needs.",
    created_days=0,
    scheduled_days=0,
    scheduled_hours=-2,
    logged_days=0,
    creator=actor_id,
)

impact_catalogue = make_work(
    "task",
    impacts,
    "Update impact event catalogue",
    "Review three candidate events and update metadata.",
    status="todo",
    created_days=-4,
    deadline_days=7,
    creator=actor_id,
)

candidate_note = make_work(
    "note",
    impacts,
    "Candidate event quality",
    "Event C has a weak high-frequency onset and should remain flagged as uncertain.",
    parent=impact_catalogue,
    created_days=-1,
    logged_days=-1,
    creator=actor_id,
)

make_relation(
    prepare_seminar,
    maya,
    "requestedBy",
    True,
)

make_relation(
    prepare_seminar,
    elena,
    "with",
    True,
)

make_relation(
    prepare_seminar,
    earth_dept,
    "forWhom",
    True,
)

make_relation(
    manuscript,
    sofia,
    "with",
    True,
)

make_relation(
    manuscript,
    mars_collab,
    "relatedTo",
    True,
)

make_relation(
    manuscript,
    elena,
    "assignedTo",
    True,
)

make_relation(
    ceph,
    lucas,
    "assignedTo",
    True,
)

make_relation(
    ceph,
    data_team,
    "relatedTo",
    True,
)

make_relation(
    dreport,
    amina,
    "with",
    True,
)

make_relation(
    dreport,
    open_working_group,
    "relatedTo",
    False,
)

make_relation(
    expenses,
    daniel,
    "requestedBy",
    False,
)

make_relation(
    workshop,
    omar,
    "with",
    True,
)

make_relation(
    workshop,
    open_science,
    "forWhom",
    True,
)

make_relation(
    paper_reading,
    martin,
    "relatedTo",
    False,
)

make_relation(
    team_meeting,
    elena,
    "with",
    False,
)

make_relation(
    team_meeting,
    sofia,
    "with",
    False,
)

make_relation(
    team_meeting,
    ana,
    "with",
    False,
)

make_relation(
    impact_catalogue,
    kenji,
    "with",
    True,
)

data["schemaVersion"] = max(
    int(
        data.get(
            "schemaVersion",
            1
        )
    ),
    4,
)

data_path.write_text(
    json.dumps(
        data,
        indent=2,
        ensure_ascii=False,
    )
    + "\n"
)

manifest["generatedAt"] = (
    datetime.now(
        timezone.utc
    )
    .isoformat()
)

manifest_path.write_text(
    json.dumps(
        manifest,
        indent=2,
    )
    + "\n"
)

print("Dataset installed.")
print()
print("Added:")
print(
    "  Themes:",
    len(manifest["themes"])
)
print(
    "  Work items:",
    len(manifest["workItems"])
)
print(
    "  Entities:",
    len(manifest["entities"])
)
print(
    "  Person profiles:",
    len(manifest["personProfiles"])
)
print(
    "  Memberships:",
    len(manifest["memberships"])
)
print(
    "  Work relationships:",
    len(
        manifest[
            "workEntityRelationships"
        ]
    )
)
print(
    "  Test users:",
    len(manifest["users"])
)
print()

test_users = [
    user
    for user in data["users"]
    if user.get("id")
    in set(manifest["users"])
]

if test_users:
    print("Test login credentials:")
    print()

    for user in test_users:
        print(
            " ",
            user["username"],
            " / DReportTest!2026",
            " [",
            user.get(
                "role",
                "member"
            ),
            ", ",
            "active"
            if user.get(
                "isActive",
                True
            )
            else "disabled",
            "]",
            sep="",
        )

print()
print(
    "Existing non-test users and data were preserved."
)
PY

echo
echo "=========================================="
echo "  STARTING DREPORT"
echo "=========================================="
echo

open "$PWD/dist/DReport.app"

echo
echo "Done."
echo
echo "To load the dataset again later:"
echo "  cd \"$PWD\""
echo "  ./Scripts/load-test-dataset.sh"
echo
echo "Backup created at:"
echo "  $BACKUP"
