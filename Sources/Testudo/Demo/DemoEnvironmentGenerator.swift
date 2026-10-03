import Foundation


// ============================================================
// MARK: - Demo package marker
//
// This file exists only inside Testudo-managed Demo packages.
// It is deliberately separate from EnvironmentManifest so the
// portable Environment schema does not need a Demo-only field.
// ============================================================

struct DemoEnvironmentMarker:
    Codable,
    Hashable
{
    var schemaVersion:
        Int = 1

    var contentVersion:
        String = "university-science-v1"

    var generatedAt:
        Date

    var rangeStart:
        Date

    var rangeEnd:
        Date

    var displayName:
        String
}


// ============================================================
// MARK: - Generated payload
// ============================================================

struct DemoEnvironmentPayload
{
    var data:
        TestudoData

    var administratorMembershipID:
        UUID

    var rangeStart:
        Date

    var rangeEnd:
        Date
}


// ============================================================
// MARK: - Business-time clock
//
// Offset 0 means the nearest current/next business day.
//
// All generated operational dates are Monday–Friday and use
// normal working hours.
// ============================================================

private struct DemoBusinessClock
{
    private var calendar:
        Calendar

    private var anchor:
        Date


    init(
        now:
            Date,
        timeZoneID:
            String
    ) {

        var calendar =
            Calendar(
                identifier:
                    .gregorian
            )

        calendar.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        calendar.timeZone =
            TimeZone(
                identifier:
                    timeZoneID
            )
            ?? .current


        var anchor =
            calendar
                .startOfDay(
                    for:
                        now
                )


        while
            calendar
                .isDateInWeekend(
                    anchor
                )
        {
            anchor =
                calendar
                    .date(
                        byAdding:
                            .day,
                        value:
                            1,
                        to:
                            anchor
                    )
                ?? anchor
        }


        self.calendar =
            calendar

        self.anchor =
            anchor
    }


    func date(
        _ businessDayOffset:
            Int,
        hour:
            Int = 10,
        minute:
            Int = 0
    ) -> Date {

        var day =
            anchor


        if businessDayOffset != 0 {

            let direction =
                businessDayOffset > 0
                ? 1
                : -1

            var remaining =
                abs(
                    businessDayOffset
                )


            while remaining > 0 {

                day =
                    calendar
                        .date(
                            byAdding:
                                .day,
                            value:
                                direction,
                            to:
                                day
                        )
                    ?? day


                if
                    !calendar
                        .isDateInWeekend(
                            day
                        )
                {
                    remaining -= 1
                }
            }
        }


        var components =
            calendar
                .dateComponents(
                    [
                        .year,
                        .month,
                        .day,
                    ],
                    from:
                        day
                )

        components.hour =
            hour

        components.minute =
            minute

        components.second =
            0


        return
            calendar
                .date(
                    from:
                        components
                )
            ?? day
    }
}


// ============================================================
// MARK: - Fixed fictional people
// ============================================================

private struct DemoPersonSeed
{
    let key:
        String

    let firstName:
        String

    let lastName:
        String

    let academicTitle:
        String?

    let jobTitle:
        String

    let email:
        String

    let fields:
        String

    let responsibilities:
        String

    let city:
        String

    let country:
        String

    let timeZone:
        String

    let primaryAffiliation:
        String

    let secondaryAffiliation:
        String?
}


// ============================================================
// MARK: - Project seeds
// ============================================================

private struct DemoProjectSeed
{
    let key:
        String

    let theme:
        String

    let secondaryTheme:
        String?

    let title:
        String

    let summary:
        String

    let status:
        TaskStatus

    let created:
        Int

    let deadline:
        Int?

    let assignedPerson:
        String

    let requestedBy:
        String

    let partner:
        String

    let children:
        [String]

    let noteTitle:
        String

    let noteBody:
        String

    let eventTitle:
        String

    let eventBody:
        String
}


// ============================================================
// MARK: - Calendar seeds
// ============================================================

private struct DemoCalendarSeed
{
    let title:
        String

    let businessDay:
        Int

    let hour:
        Int

    let durationMinutes:
        Int

    let location:
        String

    let theme:
        String

    let project:
        String?

    let attendees:
        [String]
}


// ============================================================
// MARK: - Generator
// ============================================================

enum DemoEnvironmentGenerator
{
    static func make(
        environmentID:
            UUID,
        localProfile:
            LocalUserProfile,
        generatedAt:
            Date
    ) -> DemoEnvironmentPayload {

        let timeZoneID =
            localProfile
                .timeZone?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .isEmpty
                == false
            ? localProfile.timeZone!
            : TimeZone
                .current
                .identifier


        let clock =
            DemoBusinessClock(
                now:
                    generatedAt,
                timeZoneID:
                    timeZoneID
            )


        let rangeStart =
            clock.date(
                -22,
                hour:
                    9
            )

        let rangeEnd =
            clock.date(
                44,
                hour:
                    17
            )


        var data =
            TestudoData()

        data.schemaVersion =
            max(
                data.schemaVersion,
                8
            )


        var themes:
            [String: UUID] =
            [:]

        var entities:
            [String: UUID] =
            [:]

        var people:
            [String: UUID] =
            [:]

        var peopleEmails:
            [String: String] =
            [:]

        var projects:
            [String: UUID] =
            [:]


        // ====================================================
        // MARK: Theme helpers
        // ====================================================

        @discardableResult
        func addTheme(
            _ key:
                String,
            name:
                String,
            notes:
                String,
            parent:
                String? = nil,
            symbol:
                String? = nil
        ) -> UUID {

            var theme =
                Theme(
                    name:
                        name
                )

            theme.notes =
                notes

            theme.symbolName =
                symbol

            theme.createdAt =
                clock.date(
                    -22,
                    hour:
                        9
                )

            theme.updatedAt =
                clock.date(
                    -1,
                    hour:
                        16
                )


            if
                let parent,
                let parentID =
                    themes[parent]
            {
                theme.parentThemeID =
                    parentID
            }


            data.themes.append(
                theme
            )

            themes[key] =
                theme.id


            return theme.id
        }


        // ====================================================
        // MARK: Entity helpers
        // ====================================================

        @discardableResult
        func addEntity(
            _ key:
                String,
            kind:
                EntityKind,
            name:
                String,
            notes:
                String,
            shortName:
                String? = nil,
            city:
                String? = nil,
            country:
                String? = nil,
            website:
                String? = nil
        ) -> UUID {

            var entity =
                Entity(
                    kind:
                        kind,
                    name:
                        name
                )

            entity.notes =
                notes

            entity.shortName =
                shortName

            entity.city =
                city

            entity.country =
                country

            entity.website =
                website

            entity.createdAt =
                clock.date(
                    -22,
                    hour:
                        9
                )

            entity.updatedAt =
                clock.date(
                    -2,
                    hour:
                        15
                )


            data.entities.append(
                entity
            )

            entities[key] =
                entity.id


            return entity.id
        }


        func addMembership(
            member:
                UUID,
            container:
                UUID,
            primary:
                Bool = false
        ) {

            var membership =
                EntityMembership(
                    memberEntityID:
                        member,
                    containerEntityID:
                        container
                )

            membership.isPrimary =
                primary

            membership.createdAt =
                clock.date(
                    -21,
                    hour:
                        10
                )


            data.memberships.append(
                membership
            )
        }


        // ====================================================
        // MARK: Person helpers
        // ====================================================

        @discardableResult
        func addDemoPerson(
            _ seed:
                DemoPersonSeed
        ) -> UUID {

            var entity =
                Entity(
                    kind:
                        .person,
                    name:
                        "\(seed.firstName) \(seed.lastName)"
                )

            entity.notes =
                "Fictional Testudo Demo collaborator."

            entity.email =
                seed.email

            entity.city =
                seed.city

            entity.country =
                seed.country

            entity.createdAt =
                clock.date(
                    -21,
                    hour:
                        10
                )

            entity.updatedAt =
                clock.date(
                    -2,
                    hour:
                        15
                )


            data.entities.append(
                entity
            )


            var profile =
                PersonProfile(
                    entityID:
                        entity.id
                )

            profile.firstName =
                seed.firstName

            profile.lastName =
                seed.lastName

            profile.academicTitle =
                seed.academicTitle

            profile.jobTitle =
                seed.jobTitle

            profile.professionalEmail =
                seed.email

            profile.professionalFields =
                seed.fields

            profile.responsibilities =
                seed.responsibilities

            profile.city =
                seed.city

            profile.country =
                seed.country

            profile.timeZone =
                seed.timeZone

            profile.preferredLanguage =
                "English"

            profile.tags =
                seed.fields

            profile.createdAt =
                clock.date(
                    -21,
                    hour:
                        10
                )

            profile.updatedAt =
                clock.date(
                    -2,
                    hour:
                        15
                )


            data.personProfiles.append(
                profile
            )


            people[seed.key] =
                entity.id

            peopleEmails[seed.key] =
                seed.email


            if
                let primary =
                    entities[
                        seed.primaryAffiliation
                    ]
            {
                addMembership(
                    member:
                        entity.id,
                    container:
                        primary,
                    primary:
                        true
                )
            }


            if
                let secondaryKey =
                    seed.secondaryAffiliation,
                let secondary =
                    entities[
                        secondaryKey
                    ]
            {
                addMembership(
                    member:
                        entity.id,
                    container:
                        secondary,
                    primary:
                        false
                )
            }


            return entity.id
        }


        // ====================================================
        // MARK: Work helpers
        // ====================================================

        func addHistory(
            workItemID:
                UUID,
            kind:
                HistoryEventKind,
            timestamp:
                Date,
            actorMembershipID:
                UUID,
            text:
                String
        ) {

            var history =
                HistoryEvent(
                    workItemID:
                        workItemID,
                    kind:
                        kind
                )

            history.timestamp =
                timestamp

            history.text =
                text

            history.actorMembershipID =
                actorMembershipID

            history.timeZoneID =
                timeZoneID


            data.historyEvents.append(
                history
            )
        }


        func addWork(
            kind:
                WorkItemKind,
            themeKeys:
                [String],
            title:
                String,
            body:
                String,
            parent:
                UUID? = nil,
            status:
                TaskStatus? = nil,
            created:
                Int,
            deadline:
                Int? = nil,
            reminder:
                Int? = nil,
            started:
                Int? = nil,
            completed:
                Int? = nil,
            logged:
                Int? = nil,
            actorMembershipID:
                UUID
        ) -> UUID {

            var item =
                WorkItem(
                    kind:
                        kind
                )

            let themeIDs =
                themeKeys
                    .compactMap {
                        themes[$0]
                    }


            item.themeID =
                themeIDs.first

            item.themeIDs =
                themeIDs

            item.parentWorkItemID =
                parent

            item.title =
                title

            item.body =
                body

            item.status =
                status

            item.createdAt =
                clock.date(
                    created,
                    hour:
                        10
                )

            item.updatedAt =
                clock.date(
                    min(
                        0,
                        max(
                            created,
                            -1
                        )
                    ),
                    hour:
                        16
                )


            if let deadline {
                item.deadlineAt =
                    clock.date(
                        deadline,
                        hour:
                            16
                    )
            }


            if let reminder {
                item.reminderAt =
                    clock.date(
                        reminder,
                        hour:
                            9
                    )
            }


            if let started {
                item.startedAt =
                    clock.date(
                        started,
                        hour:
                            9
                    )
            }


            if let completed {
                item.completedAt =
                    clock.date(
                        completed,
                        hour:
                            16
                    )
            }


            if let logged {
                item.loggedAt =
                    clock.date(
                        logged,
                        hour:
                            15
                    )
            }


            item.createdByMembershipID =
                actorMembershipID

            item.updatedByMembershipID =
                actorMembershipID

            item.createdTimeZoneID =
                timeZoneID

            item.updatedTimeZoneID =
                timeZoneID

            item.deadlineTimeZoneID =
                item.deadlineAt == nil
                ? nil
                : timeZoneID

            item.reminderTimeZoneID =
                item.reminderAt == nil
                ? nil
                : timeZoneID

            item.startedTimeZoneID =
                item.startedAt == nil
                ? nil
                : timeZoneID

            item.completedTimeZoneID =
                item.completedAt == nil
                ? nil
                : timeZoneID

            item.loggedTimeZoneID =
                item.loggedAt == nil
                ? nil
                : timeZoneID


            data.workItems.append(
                item
            )


            addHistory(
                workItemID:
                    item.id,
                kind:
                    .created,
                timestamp:
                    item.createdAt,
                actorMembershipID:
                    actorMembershipID,
                text:
                    "Created in the Testudo Demo Environment."
            )


            if
                let startedAt =
                    item.startedAt
            {
                addHistory(
                    workItemID:
                        item.id,
                    kind:
                        .started,
                    timestamp:
                        startedAt,
                    actorMembershipID:
                        actorMembershipID,
                    text:
                        "Work started."
                )
            }


            if
                let completedAt =
                    item.completedAt
            {
                addHistory(
                    workItemID:
                        item.id,
                    kind:
                        .completed,
                    timestamp:
                        completedAt,
                    actorMembershipID:
                        actorMembershipID,
                    text:
                        "Work completed."
                )
            }


            if
                kind == .activity,
                let loggedAt =
                    item.loggedAt
            {
                addHistory(
                    workItemID:
                        item.id,
                    kind:
                        .activityLogged,
                    timestamp:
                        loggedAt,
                    actorMembershipID:
                        actorMembershipID,
                    text:
                        "Event recorded in the project history."
                )
            }


            return item.id
        }


        func addRelationship(
            workItemID:
                UUID,
            entityKey:
                String,
            role:
                WorkRelationshipRole,
            inherited:
                Bool = true
        ) {

            guard
                let entityID =
                    entities[entityKey]
                    ?? people[entityKey]
            else {
                return
            }


            var relationship =
                WorkEntityRelationship(
                    workItemID:
                        workItemID,
                    entityID:
                        entityID,
                    role:
                        role
                )

            relationship.inheritedByChildren =
                inherited

            relationship.createdAt =
                clock.date(
                    -3,
                    hour:
                        11
                )


            data
                .workEntityRelationships
                .append(
                    relationship
                )
        }


        // ====================================================
        // MARK: Themes
        // ====================================================

        addTheme(
            "softwareRoot",
            name:
                "Software & Computing",
            notes:
                "Research software engineering, computation and digital infrastructure.",
            symbol:
                "chevron.left.forwardslash.chevron.right"
        )

        addTheme(
            "rse",
            name:
                "Research Software Engineering",
            notes:
                "Scientific software architecture, development, testing and releases.",
            parent:
                "softwareRoot",
            symbol:
                "terminal"
        )

        addTheme(
            "hpc",
            name:
                "Scientific Computing & HPC",
            notes:
                "High-performance computing, workflow optimisation and numerical platforms.",
            parent:
                "softwareRoot",
            symbol:
                "cpu"
        )

        addTheme(
            "dataInfra",
            name:
                "Data Infrastructure",
            notes:
                "Scientific storage, databases, data portals and resilient services.",
            parent:
                "softwareRoot",
            symbol:
                "externaldrive"
        )

        addTheme(
            "ai",
            name:
                "AI & Data Science",
            notes:
                "Statistical learning, surrogate models and scientific machine learning.",
            parent:
                "softwareRoot",
            symbol:
                "brain"
        )


        addTheme(
            "scienceRoot",
            name:
                "Scientific Research",
            notes:
                "Cross-disciplinary research across the physical, life and environmental sciences.",
            symbol:
                "atom"
        )

        addTheme(
            "earth",
            name:
                "Earth & Environmental Sciences",
            notes:
                "Geophysics, climate, oceans, hazards and Earth observation.",
            parent:
                "scienceRoot",
            symbol:
                "globe.europe.africa"
        )

        addTheme(
            "physics",
            name:
                "Physics & Astronomy",
            notes:
                "Astrophysics, photonics, quantum systems and scientific instrumentation.",
            parent:
                "scienceRoot",
            symbol:
                "sparkles"
        )

        addTheme(
            "biology",
            name:
                "Computational Biology",
            notes:
                "Genomics, bioinformatics and reproducible life-science workflows.",
            parent:
                "scienceRoot",
            symbol:
                "leaf"
        )

        addTheme(
            "materials",
            name:
                "Chemistry & Materials",
            notes:
                "Molecular simulation, spectroscopy and computational materials science.",
            parent:
                "scienceRoot",
            symbol:
                "hexagon"
        )

        addTheme(
            "instrumentation",
            name:
                "Instrumentation & Sensors",
            notes:
                "Scientific sensors, acquisition systems and laboratory integration.",
            parent:
                "scienceRoot",
            symbol:
                "sensor"
        )


        addTheme(
            "collaborationRoot",
            name:
                "Collaboration & Open Science",
            notes:
                "International partnerships, FAIR research practice and scientific exchange.",
            symbol:
                "person.3"
        )

        addTheme(
            "international",
            name:
                "International Collaborations",
            notes:
                "Multi-institution projects, research networks and consortium coordination.",
            parent:
                "collaborationRoot",
            symbol:
                "network"
        )

        addTheme(
            "openScience",
            name:
                "Open Science & FAIR Data",
            notes:
                "Reproducibility, metadata, research data management and open research.",
            parent:
                "collaborationRoot",
            symbol:
                "lock.open"
        )

        addTheme(
            "training",
            name:
                "Seminars & Training",
            notes:
                "Scientific seminars, workshops, training and visiting researchers.",
            parent:
                "collaborationRoot",
            symbol:
                "person.2.wave.2"
        )

        addTheme(
            "administration",
            name:
                "Research Administration",
            notes:
                "Proposals, travel, reporting, procurement and institutional coordination.",
            symbol:
                "doc.text"
        )


        // ====================================================
        // MARK: Organizations
        // ====================================================

        let meridian =
            addEntity(
                "meridian",
                kind:
                    .organization,
                name:
                    "Meridian Institute of Science and Technology",
                notes:
                    "Fictional international research university hosting the Demo Environment.",
                shortName:
                    "MIST",
                city:
                    "Lyon",
                country:
                    "France",
                website:
                    "https://example.test/mist"
            )

        let physicalSchool =
            addEntity(
                "physicalSchool",
                kind:
                    .organization,
                name:
                    "School of Physical & Computational Sciences",
                notes:
                    "Academic school covering physics, Earth science, computation and engineering.",
                shortName:
                    "SPCS",
                city:
                    "Lyon",
                country:
                    "France"
            )

        let computingCentre =
            addEntity(
                "computingCentre",
                kind:
                    .organization,
                name:
                    "Centre for Research Computing",
                notes:
                    "Institutional research-computing and scientific-software centre.",
                shortName:
                    "CRC",
                city:
                    "Lyon",
                country:
                    "France"
            )

        let earthDepartment =
            addEntity(
                "earthDepartment",
                kind:
                    .organization,
                name:
                    "Department of Earth & Environmental Systems",
                notes:
                    "Geophysics, climate, hazards and Earth-system research.",
                shortName:
                    "DEES",
                city:
                    "Lyon",
                country:
                    "France"
            )

        let lifeInstitute =
            addEntity(
                "lifeInstitute",
                kind:
                    .organization,
                name:
                    "Institute for Computational Life Sciences",
                notes:
                    "Computational biology and biomedical data research.",
                shortName:
                    "ICLS",
                city:
                    "Lyon",
                country:
                    "France"
            )

        let quantumCentre =
            addEntity(
                "quantumCentre",
                kind:
                    .organization,
                name:
                    "Quantum & Photonics Centre",
                notes:
                    "Experimental and computational physics research centre.",
                shortName:
                    "QPC",
                city:
                    "Lyon",
                country:
                    "France"
            )

        let materialsLab =
            addEntity(
                "materialsLab",
                kind:
                    .organization,
                name:
                    "Advanced Materials Laboratory",
                notes:
                    "Materials simulation, spectroscopy and computational chemistry.",
                shortName:
                    "AML",
                city:
                    "Lyon",
                country:
                    "France"
            )


        addEntity(
            "ersa",
            kind:
                .organization,
            name:
                "European Research Software Alliance",
            notes:
                "Fictional European network for sustainable research software.",
            shortName:
                "ERSA",
            city:
                "Brussels",
            country:
                "Belgium"
        )

        addEntity(
            "nordicClimate",
            kind:
                .organization,
            name:
                "Nordic Climate Centre",
            notes:
                "Fictional climate-modelling and Earth-system institute.",
            shortName:
                "NCC",
            city:
                "Stockholm",
            country:
                "Sweden"
        )

        addEntity(
            "pacificObservatory",
            kind:
                .organization,
            name:
                "Pacific Observatory Network",
            notes:
                "Fictional international geophysical and astronomical observing network.",
            shortName:
                "PON",
            city:
                "Wellington",
            country:
                "New Zealand"
        )

        addEntity(
            "helios",
            kind:
                .organization,
            name:
                "Helios Space Research Agency",
            notes:
                "Fictional space-science and planetary-research organisation.",
            shortName:
                "HSRA",
            city:
                "Madrid",
            country:
                "Spain"
        )

        addEntity(
            "atlasBio",
            kind:
                .organization,
            name:
                "Atlas Bioinformatics Institute",
            notes:
                "Fictional international bioinformatics research institute.",
            shortName:
                "ABI",
            city:
                "Cambridge",
            country:
                "United Kingdom"
        )

        addEntity(
            "alpineData",
            kind:
                .organization,
            name:
                "Alpine Scientific Data Centre",
            notes:
                "Fictional scientific storage and data-service centre.",
            shortName:
                "ASDC",
            city:
                "Geneva",
            country:
                "Switzerland"
        )


        addMembership(
            member:
                physicalSchool,
            container:
                meridian,
            primary:
                true
        )

        addMembership(
            member:
                computingCentre,
            container:
                meridian,
            primary:
                true
        )

        addMembership(
            member:
                earthDepartment,
            container:
                physicalSchool,
            primary:
                true
        )

        addMembership(
            member:
                lifeInstitute,
            container:
                meridian,
            primary:
                true
        )

        addMembership(
            member:
                quantumCentre,
            container:
                physicalSchool,
            primary:
                true
        )

        addMembership(
            member:
                materialsLab,
            container:
                physicalSchool,
            primary:
                true
        )


        // ====================================================
        // MARK: Groups
        // ====================================================

        func group(
            _ key:
                String,
            _ name:
                String,
            _ notes:
                String,
            inside:
                String? = nil
        ) {

            let groupID =
                addEntity(
                    key,
                    kind:
                        .group,
                    name:
                        name,
                    notes:
                        notes
                )


            if
                let inside,
                let container =
                    entities[inside]
            {
                addMembership(
                    member:
                        groupID,
                    container:
                        container,
                    primary:
                        true
                )
            }
        }


        group(
            "rseUnit",
            "Research Software Engineering Unit",
            "Research software engineers supporting scientific projects across the institute.",
            inside:
                "computingCentre"
        )

        group(
            "hpcOps",
            "HPC Operations Team",
            "High-performance computing platforms, schedulers and performance engineering.",
            inside:
                "computingCentre"
        )

        group(
            "dataSystems",
            "Scientific Data Systems Group",
            "Storage, databases, data portals, preservation and research data services.",
            inside:
                "computingCentre"
        )

        group(
            "seismicLab",
            "Seismic Imaging Laboratory",
            "Seismology, tomography, hazards and planetary geophysics.",
            inside:
                "earthDepartment"
        )

        group(
            "climateGroup",
            "Climate Dynamics Group",
            "Climate modelling, ocean-atmosphere coupling and Earth-system simulations.",
            inside:
                "earthDepartment"
        )

        group(
            "astroPipelines",
            "Astronomy Data Pipelines Group",
            "Scientific pipelines for telescope and space-observatory data.",
            inside:
                "quantumCentre"
        )

        group(
            "genomicsTeam",
            "Genomics Workflow Team",
            "Scalable bioinformatics workflows and reproducible genomics.",
            inside:
                "lifeInstitute"
        )

        group(
            "molecularSim",
            "Molecular Simulation Group",
            "Molecular dynamics, materials modelling and computational chemistry.",
            inside:
                "materialsLab"
        )

        group(
            "sensorsLab",
            "Instrumentation & Sensor Systems Lab",
            "Embedded acquisition, environmental sensors and scientific instrumentation.",
            inside:
                "physicalSchool"
        )

        group(
            "openScienceWG",
            "Open Science & FAIR Working Group",
            "Cross-disciplinary working group for reproducibility, metadata and open research.",
            inside:
                "meridian"
        )

        group(
            "internationalSoftware",
            "International Research Software Consortium",
            "Cross-institution collaboration on sustainable scientific software.",
            inside:
                "ersa"
        )

        group(
            "seminarCommittee",
            "Scientific Seminar Committee",
            "Coordinates seminars, visitors and cross-disciplinary training.",
            inside:
                "meridian"
        )


        // ====================================================
        // MARK: Current Testudo user = Demo Administrator
        // ====================================================

        let adminDisplayName =
            localProfile
                .displayName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        var adminEntity =
            Entity(
                kind:
                    .person,
                name:
                    adminDisplayName.isEmpty
                    ? "Testudo User"
                    : adminDisplayName
            )

        adminEntity.notes =
            "Current Testudo application user and Administrator of this generated Demo Environment."

        adminEntity.email =
            localProfile
                .professionalEmail
                .isEmpty
            ? nil
            : localProfile
                .professionalEmail

        adminEntity.phone =
            localProfile
                .professionalPhone
                .isEmpty
            ? nil
            : localProfile
                .professionalPhone

        adminEntity.website =
            localProfile
                .website
                .isEmpty
            ? nil
            : localProfile
                .website

        adminEntity.address =
            localProfile
                .professionalAddress

        adminEntity.city =
            localProfile
                .city

        adminEntity.postalCode =
            localProfile
                .postalCode

        adminEntity.country =
            localProfile
                .country

        adminEntity.tags =
            localProfile
                .tags

        adminEntity.createdAt =
            clock.date(
                -22,
                hour:
                    9
            )

        adminEntity.updatedAt =
            clock.date(
                -1,
                hour:
                    16
            )


        data.entities.append(
            adminEntity
        )

        people["appUser"] =
            adminEntity.id

        peopleEmails["appUser"] =
            localProfile
                .professionalEmail


        var adminProfile =
            PersonProfile(
                entityID:
                    adminEntity.id
            )

        adminProfile.firstName =
            localProfile.firstName

        adminProfile.middleName =
            localProfile.middleName

        adminProfile.lastName =
            localProfile.lastName

        adminProfile.preferredName =
            localProfile.preferredName

        adminProfile.jobTitle =
            localProfile.jobTitle

        adminProfile.professionalEmail =
            localProfile.professionalEmail

        adminProfile.secondaryProfessionalEmail =
            localProfile.secondaryProfessionalEmail

        adminProfile.professionalPhone =
            localProfile.professionalPhone

        adminProfile.secondaryPhone =
            localProfile.secondaryPhone

        adminProfile.office =
            localProfile.office

        adminProfile.employeeID =
            localProfile.employeeID

        adminProfile.website =
            localProfile.website

        adminProfile.orcid =
            localProfile.orcid

        adminProfile.linkedIn =
            localProfile.linkedIn

        adminProfile.github =
            localProfile.github

        adminProfile.professionalFields =
            localProfile.professionalFields

        adminProfile.responsibilities =
            localProfile.responsibilities

        adminProfile.notes =
            localProfile.notes

        adminProfile.avatarData =
            localProfile.avatarData

        adminProfile.academicTitle =
            localProfile.academicTitle

        adminProfile.professionalAddress =
            localProfile.professionalAddress

        adminProfile.city =
            localProfile.city

        adminProfile.postalCode =
            localProfile.postalCode

        adminProfile.country =
            localProfile.country

        adminProfile.researcherID =
            localProfile.researcherID

        adminProfile.scopusAuthorID =
            localProfile.scopusAuthorID

        adminProfile.googleScholarURL =
            localProfile.googleScholarURL

        adminProfile.preferredLanguage =
            localProfile.preferredLanguage

        adminProfile.timeZone =
            localProfile.timeZone

        adminProfile.assistantContact =
            localProfile.assistantContact

        adminProfile.tags =
            localProfile.tags

        adminProfile.createdAt =
            clock.date(
                -22,
                hour:
                    9
            )

        adminProfile.updatedAt =
            clock.date(
                -1,
                hour:
                    16
            )


        data.personProfiles.append(
            adminProfile
        )


        addMembership(
            member:
                adminEntity.id,
            container:
                entities["rseUnit"]!,
            primary:
                true
        )

        addMembership(
            member:
                adminEntity.id,
            container:
                entities["openScienceWG"]!,
            primary:
                false
        )


        let applicationUsername:
            String =
        {
            let email =
                localProfile
                    .professionalEmail
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if !email.isEmpty {
                return email
            }


            let raw =
                "\(localProfile.firstName).\(localProfile.lastName)"
                    .folding(
                        options:
                            [
                                .diacriticInsensitive,
                                .caseInsensitive,
                            ],
                        locale:
                            Locale(
                                identifier:
                                    "en_US_POSIX"
                            )
                    )
                    .lowercased()


            let cleaned =
                raw
                    .map {
                        character
                        in

                        character
                            .isLetter
                            || character
                                .isNumber
                        ? String(
                            character
                        )
                        : "."
                    }
                    .joined()
                    .split(
                        separator:
                            "."
                    )
                    .filter {
                        !$0.isEmpty
                    }
                    .joined(
                        separator:
                            "."
                    )


            return
                cleaned.isEmpty
                ? "demo.administrator"
                : cleaned
        }()


        let administratorMembership =
            EnvironmentMembership(
                environmentID:
                    environmentID,
                localUserProfileID:
                    nil,
                personEntityID:
                    adminEntity.id,
                directoryUserIdentifier:
                    applicationUsername,
                firstName:
                    localProfile.firstName,
                lastName:
                    localProfile.lastName,
                role:
                    .administrator,
                isActive:
                    true,
                createdAt:
                    clock.date(
                        -22,
                        hour:
                            9
                    ),
                lastAccessAt:
                    generatedAt
            )


        data
            .environmentMemberships
            .append(
                administratorMembership
            )


        // ====================================================
        // MARK: Demo collaborators
        // ====================================================

        let personSeeds:
            [DemoPersonSeed] =
            [
                DemoPersonSeed(
                    key: "amina",
                    firstName: "Amina",
                    lastName: "Benali",
                    academicTitle: "Dr.",
                    jobTitle: "Senior Research Software Engineer",
                    email: "amina.benali@example.test",
                    fields: "Research software; Python; workflow systems; software architecture",
                    responsibilities: "Scientific software architecture; code review; reproducible workflows",
                    city: "Lyon",
                    country: "France",
                    timeZone: "Europe/Paris",
                    primaryAffiliation: "rseUnit",
                    secondaryAffiliation: "internationalSoftware"
                ),

                DemoPersonSeed(
                    key: "elena",
                    firstName: "Elena",
                    lastName: "Rossi",
                    academicTitle: "Dr.",
                    jobTitle: "Senior Seismologist",
                    email: "elena.rossi@example.test",
                    fields: "Seismology; tomography; planetary geophysics",
                    responsibilities: "Seismic imaging; waveform analysis; doctoral supervision",
                    city: "Bologna",
                    country: "Italy",
                    timeZone: "Europe/Rome",
                    primaryAffiliation: "seismicLab",
                    secondaryAffiliation: "pacificObservatory"
                ),

                DemoPersonSeed(
                    key: "lucas",
                    firstName: "Lucas",
                    lastName: "Martin",
                    academicTitle: nil,
                    jobTitle: "Scientific Infrastructure Engineer",
                    email: "lucas.martin@example.test",
                    fields: "Linux; Ceph; networking; scientific storage",
                    responsibilities: "Storage services; backups; resilient infrastructure",
                    city: "Lyon",
                    country: "France",
                    timeZone: "Europe/Paris",
                    primaryAffiliation: "dataSystems",
                    secondaryAffiliation: "alpineData"
                ),

                DemoPersonSeed(
                    key: "mateo",
                    firstName: "Mateo",
                    lastName: "Álvarez",
                    academicTitle: "Dr.",
                    jobTitle: "Climate Modeller",
                    email: "mateo.alvarez@example.test",
                    fields: "Climate dynamics; ocean-atmosphere modelling",
                    responsibilities: "Climate simulations; model intercomparison",
                    city: "Barcelona",
                    country: "Spain",
                    timeZone: "Europe/Madrid",
                    primaryAffiliation: "climateGroup",
                    secondaryAffiliation: "nordicClimate"
                ),

                DemoPersonSeed(
                    key: "priya",
                    firstName: "Priya",
                    lastName: "Nair",
                    academicTitle: "Dr.",
                    jobTitle: "Computational Biologist",
                    email: "priya.nair@example.test",
                    fields: "Bioinformatics; genomics; workflow reproducibility",
                    responsibilities: "Genomics pipelines; consortium data processing",
                    city: "Cambridge",
                    country: "United Kingdom",
                    timeZone: "Europe/London",
                    primaryAffiliation: "genomicsTeam",
                    secondaryAffiliation: "atlasBio"
                ),

                DemoPersonSeed(
                    key: "yuki",
                    firstName: "Yuki",
                    lastName: "Tanaka",
                    academicTitle: "Dr.",
                    jobTitle: "Astrophysicist",
                    email: "yuki.tanaka@example.test",
                    fields: "Exoplanets; astronomical pipelines; time-series analysis",
                    responsibilities: "Telescope data pipelines; transit analysis",
                    city: "Tokyo",
                    country: "Japan",
                    timeZone: "Asia/Tokyo",
                    primaryAffiliation: "astroPipelines",
                    secondaryAffiliation: "helios"
                ),

                DemoPersonSeed(
                    key: "sofia",
                    firstName: "Sofia",
                    lastName: "Papadopoulou",
                    academicTitle: "Dr.",
                    jobTitle: "Geophysics Research Fellow",
                    email: "sofia.papadopoulou@example.test",
                    fields: "Attenuation; inverse problems; crustal structure",
                    responsibilities: "Waveform processing; inversion; manuscript preparation",
                    city: "Athens",
                    country: "Greece",
                    timeZone: "Europe/Athens",
                    primaryAffiliation: "seismicLab",
                    secondaryAffiliation: "pacificObservatory"
                ),

                DemoPersonSeed(
                    key: "noah",
                    firstName: "Noah",
                    lastName: "Müller",
                    academicTitle: nil,
                    jobTitle: "HPC Systems Engineer",
                    email: "noah.mueller@example.test",
                    fields: "HPC; Slurm; Linux; performance engineering",
                    responsibilities: "Compute platforms; scheduler operations; performance tuning",
                    city: "Zurich",
                    country: "Switzerland",
                    timeZone: "Europe/Zurich",
                    primaryAffiliation: "hpcOps",
                    secondaryAffiliation: "alpineData"
                ),

                DemoPersonSeed(
                    key: "claire",
                    firstName: "Claire",
                    lastName: "Dubois",
                    academicTitle: "Dr.",
                    jobTitle: "Open Science Officer",
                    email: "claire.dubois@example.test",
                    fields: "FAIR data; reproducibility; open research",
                    responsibilities: "Open-science policy; metadata standards; training",
                    city: "Brussels",
                    country: "Belgium",
                    timeZone: "Europe/Brussels",
                    primaryAffiliation: "openScienceWG",
                    secondaryAffiliation: "ersa"
                ),

                DemoPersonSeed(
                    key: "omar",
                    firstName: "Omar",
                    lastName: "Haddad",
                    academicTitle: nil,
                    jobTitle: "Research Data Steward",
                    email: "omar.haddad@example.test",
                    fields: "Research data management; metadata; preservation",
                    responsibilities: "Data stewardship; FAIR implementation; data-management plans",
                    city: "Algiers",
                    country: "Algeria",
                    timeZone: "Africa/Algiers",
                    primaryAffiliation: "dataSystems",
                    secondaryAffiliation: "openScienceWG"
                ),

                DemoPersonSeed(
                    key: "maya",
                    firstName: "Maya",
                    lastName: "Thompson",
                    academicTitle: nil,
                    jobTitle: "Scientific Programme Coordinator",
                    email: "maya.thompson@example.test",
                    fields: "Scientific coordination; seminars; international visits",
                    responsibilities: "Visitors; seminar programme; workshop logistics",
                    city: "London",
                    country: "United Kingdom",
                    timeZone: "Europe/London",
                    primaryAffiliation: "seminarCommittee",
                    secondaryAffiliation: "internationalSoftware"
                ),

                DemoPersonSeed(
                    key: "daniel",
                    firstName: "Daniel",
                    lastName: "Moreau",
                    academicTitle: nil,
                    jobTitle: "Research Administration Officer",
                    email: "daniel.moreau@example.test",
                    fields: "Research administration; grants; procurement",
                    responsibilities: "Travel; purchasing; project reporting",
                    city: "Lyon",
                    country: "France",
                    timeZone: "Europe/Paris",
                    primaryAffiliation: "meridian",
                    secondaryAffiliation: nil
                ),

                DemoPersonSeed(
                    key: "linh",
                    firstName: "Linh",
                    lastName: "Nguyen",
                    academicTitle: "Dr.",
                    jobTitle: "Materials Scientist",
                    email: "linh.nguyen@example.test",
                    fields: "Materials modelling; molecular dynamics",
                    responsibilities: "Simulation campaigns; model validation",
                    city: "Lyon",
                    country: "France",
                    timeZone: "Europe/Paris",
                    primaryAffiliation: "molecularSim",
                    secondaryAffiliation: nil
                ),

                DemoPersonSeed(
                    key: "samira",
                    firstName: "Samira",
                    lastName: "Khan",
                    academicTitle: "Dr.",
                    jobTitle: "Machine Learning Scientist",
                    email: "samira.khan@example.test",
                    fields: "Scientific machine learning; surrogate models",
                    responsibilities: "ML methods; model validation; scientific AI",
                    city: "Lyon",
                    country: "France",
                    timeZone: "Europe/Paris",
                    primaryAffiliation: "rseUnit",
                    secondaryAffiliation: "climateGroup"
                ),

                DemoPersonSeed(
                    key: "erik",
                    firstName: "Erik",
                    lastName: "Svensson",
                    academicTitle: "Prof.",
                    jobTitle: "Professor of Climate Dynamics",
                    email: "erik.svensson@example.test",
                    fields: "Climate dynamics; ocean circulation",
                    responsibilities: "Climate programme leadership; consortium coordination",
                    city: "Stockholm",
                    country: "Sweden",
                    timeZone: "Europe/Stockholm",
                    primaryAffiliation: "nordicClimate",
                    secondaryAffiliation: "climateGroup"
                ),

                DemoPersonSeed(
                    key: "camila",
                    firstName: "Camila",
                    lastName: "Ferreira",
                    academicTitle: "Dr.",
                    jobTitle: "Remote Sensing Scientist",
                    email: "camila.ferreira@example.test",
                    fields: "Remote sensing; environmental monitoring",
                    responsibilities: "Satellite products; geospatial processing",
                    city: "Lisbon",
                    country: "Portugal",
                    timeZone: "Europe/Lisbon",
                    primaryAffiliation: "climateGroup",
                    secondaryAffiliation: "pacificObservatory"
                ),

                DemoPersonSeed(
                    key: "kwame",
                    firstName: "Kwame",
                    lastName: "Mensah",
                    academicTitle: "Dr.",
                    jobTitle: "Instrumentation Engineer",
                    email: "kwame.mensah@example.test",
                    fields: "Scientific instrumentation; embedded systems",
                    responsibilities: "Sensor design; field acquisition systems",
                    city: "Accra",
                    country: "Ghana",
                    timeZone: "Africa/Accra",
                    primaryAffiliation: "sensorsLab",
                    secondaryAffiliation: nil
                ),

                DemoPersonSeed(
                    key: "leila",
                    firstName: "Leila",
                    lastName: "Rahmani",
                    academicTitle: "Dr.",
                    jobTitle: "Computational Chemist",
                    email: "leila.rahmani@example.test",
                    fields: "Computational chemistry; catalyst simulation",
                    responsibilities: "Electronic-structure calculations; screening workflows",
                    city: "Paris",
                    country: "France",
                    timeZone: "Europe/Paris",
                    primaryAffiliation: "molecularSim",
                    secondaryAffiliation: nil
                ),

                DemoPersonSeed(
                    key: "jonas",
                    firstName: "Jonas",
                    lastName: "Berg",
                    academicTitle: "Dr.",
                    jobTitle: "Quantum Optics Researcher",
                    email: "jonas.berg@example.test",
                    fields: "Photonics; quantum optics; numerical modelling",
                    responsibilities: "Optical simulations; experiment analysis",
                    city: "Copenhagen",
                    country: "Denmark",
                    timeZone: "Europe/Copenhagen",
                    primaryAffiliation: "quantumCentre",
                    secondaryAffiliation: nil
                ),

                DemoPersonSeed(
                    key: "hana",
                    firstName: "Hana",
                    lastName: "Kim",
                    academicTitle: "Dr.",
                    jobTitle: "Bioinformatics Scientist",
                    email: "hana.kim@example.test",
                    fields: "Genomics; variant analysis; workflow systems",
                    responsibilities: "Pipeline validation; genomic analysis",
                    city: "Seoul",
                    country: "South Korea",
                    timeZone: "Asia/Seoul",
                    primaryAffiliation: "genomicsTeam",
                    secondaryAffiliation: "atlasBio"
                ),

                DemoPersonSeed(
                    key: "ava",
                    firstName: "Ava",
                    lastName: "Wilson",
                    academicTitle: nil,
                    jobTitle: "Research Software Engineer",
                    email: "ava.wilson@example.test",
                    fields: "C++; Python; CI/CD; numerical libraries",
                    responsibilities: "Scientific libraries; testing infrastructure",
                    city: "Edinburgh",
                    country: "United Kingdom",
                    timeZone: "Europe/London",
                    primaryAffiliation: "rseUnit",
                    secondaryAffiliation: "internationalSoftware"
                ),

                DemoPersonSeed(
                    key: "diego",
                    firstName: "Diego",
                    lastName: "Morales",
                    academicTitle: "Dr.",
                    jobTitle: "Astronomy Data Scientist",
                    email: "diego.morales@example.test",
                    fields: "Astronomy; time-series; scientific pipelines",
                    responsibilities: "Pipeline benchmarking; archive processing",
                    city: "Santiago",
                    country: "Chile",
                    timeZone: "America/Santiago",
                    primaryAffiliation: "astroPipelines",
                    secondaryAffiliation: "helios"
                ),

                DemoPersonSeed(
                    key: "fatima",
                    firstName: "Fatima Zahra",
                    lastName: "El Idrissi",
                    academicTitle: "Dr.",
                    jobTitle: "Sensor Systems Scientist",
                    email: "fatima.elidrissi@example.test",
                    fields: "Environmental sensing; embedded acquisition",
                    responsibilities: "Sensor calibration; field deployments",
                    city: "Rabat",
                    country: "Morocco",
                    timeZone: "Africa/Casablanca",
                    primaryAffiliation: "sensorsLab",
                    secondaryAffiliation: nil
                ),

                DemoPersonSeed(
                    key: "nikos",
                    firstName: "Nikos",
                    lastName: "Stavrou",
                    academicTitle: "Dr.",
                    jobTitle: "Ocean Modelling Researcher",
                    email: "nikos.stavrou@example.test",
                    fields: "Oceanography; numerical modelling",
                    responsibilities: "Ocean simulations; coupled model evaluation",
                    city: "Athens",
                    country: "Greece",
                    timeZone: "Europe/Athens",
                    primaryAffiliation: "climateGroup",
                    secondaryAffiliation: "nordicClimate"
                ),

                DemoPersonSeed(
                    key: "mei",
                    firstName: "Mei",
                    lastName: "Chen",
                    academicTitle: nil,
                    jobTitle: "Scientific Visualisation Engineer",
                    email: "mei.chen@example.test",
                    fields: "Scientific visualisation; GPU rendering",
                    responsibilities: "Visual analytics; interactive research tools",
                    city: "Singapore",
                    country: "Singapore",
                    timeZone: "Asia/Singapore",
                    primaryAffiliation: "rseUnit",
                    secondaryAffiliation: nil
                ),

                DemoPersonSeed(
                    key: "ines",
                    firstName: "Inês",
                    lastName: "Costa",
                    academicTitle: nil,
                    jobTitle: "Research Data Manager",
                    email: "ines.costa@example.test",
                    fields: "Data management; preservation; FAIR metadata",
                    responsibilities: "Data-management planning; archival workflows",
                    city: "Porto",
                    country: "Portugal",
                    timeZone: "Europe/Lisbon",
                    primaryAffiliation: "dataSystems",
                    secondaryAffiliation: "openScienceWG"
                ),

                DemoPersonSeed(
                    key: "ravi",
                    firstName: "Ravi",
                    lastName: "Patel",
                    academicTitle: nil,
                    jobTitle: "HPC Performance Engineer",
                    email: "ravi.patel@example.test",
                    fields: "HPC optimisation; MPI; GPU computing",
                    responsibilities: "Performance profiling; compute optimisation",
                    city: "Lyon",
                    country: "France",
                    timeZone: "Europe/Paris",
                    primaryAffiliation: "hpcOps",
                    secondaryAffiliation: nil
                ),

                DemoPersonSeed(
                    key: "sarah",
                    firstName: "Sarah",
                    lastName: "Johnson",
                    academicTitle: nil,
                    jobTitle: "International Project Manager",
                    email: "sarah.johnson@example.test",
                    fields: "International research projects; consortium management",
                    responsibilities: "Deliverables; governance; partner coordination",
                    city: "Brussels",
                    country: "Belgium",
                    timeZone: "Europe/Brussels",
                    primaryAffiliation: "internationalSoftware",
                    secondaryAffiliation: "ersa"
                ),

                DemoPersonSeed(
                    key: "kenji",
                    firstName: "Kenji",
                    lastName: "Sato",
                    academicTitle: "Dr.",
                    jobTitle: "Planetary Scientist",
                    email: "kenji.sato@example.test",
                    fields: "Planetary science; impact physics",
                    responsibilities: "Numerical modelling; mission science collaboration",
                    city: "Tokyo",
                    country: "Japan",
                    timeZone: "Asia/Tokyo",
                    primaryAffiliation: "helios",
                    secondaryAffiliation: "seismicLab"
                ),

                DemoPersonSeed(
                    key: "ana",
                    firstName: "Ana",
                    lastName: "Torres",
                    academicTitle: nil,
                    jobTitle: "Doctoral Researcher",
                    email: "ana.torres@example.test",
                    fields: "Geophysics; inverse problems; scientific Python",
                    responsibilities: "Doctoral research; data analysis",
                    city: "Lyon",
                    country: "France",
                    timeZone: "Europe/Paris",
                    primaryAffiliation: "seismicLab",
                    secondaryAffiliation: "rseUnit"
                ),
            ]


        for seed in personSeeds {
            addDemoPerson(
                seed
            )
        }


        // ====================================================
        // MARK: Demo Environment memberships
        //
        // No credentials are generated for any membership.
        // ====================================================

        let memberKeys =
            [
                "amina",
                "elena",
                "lucas",
                "mateo",
                "priya",
                "yuki",
                "claire",
                "maya",
                "sarah",
            ]


        for key in memberKeys {

            guard
                let personID =
                    people[key],
                let seed =
                    personSeeds
                        .first(
                            where: {
                                $0.key == key
                            }
                        )
            else {
                continue
            }


            let membership =
                EnvironmentMembership(
                    environmentID:
                        environmentID,
                    localUserProfileID:
                        nil,
                    personEntityID:
                        personID,
                    directoryUserIdentifier:
                        seed.email,
                    firstName:
                        seed.firstName,
                    lastName:
                        seed.lastName,
                    role:
                        .user,
                    isActive:
                        true,
                    createdAt:
                        clock.date(
                            -20,
                            hour:
                                10
                        ),
                    lastAccessAt:
                        nil
                )


            data
                .environmentMemberships
                .append(
                    membership
                )
        }


        // ====================================================
        // MARK: Theme ↔ Entity relationships
        // ====================================================

        func linkTheme(
            _ themeKey:
                String,
            to entityKey:
                String
        ) {

            guard
                let themeID =
                    themes[themeKey],
                let entityID =
                    entities[entityKey]
            else {
                return
            }


            data
                .themeEntityRelationships
                .append(
                    ThemeEntityRelationship(
                        themeID:
                            themeID,
                        entityID:
                            entityID
                    )
                )
        }


        linkTheme(
            "rse",
            to:
                "rseUnit"
        )

        linkTheme(
            "hpc",
            to:
                "hpcOps"
        )

        linkTheme(
            "dataInfra",
            to:
                "dataSystems"
        )

        linkTheme(
            "earth",
            to:
                "earthDepartment"
        )

        linkTheme(
            "physics",
            to:
                "quantumCentre"
        )

        linkTheme(
            "biology",
            to:
                "lifeInstitute"
        )

        linkTheme(
            "materials",
            to:
                "materialsLab"
        )

        linkTheme(
            "instrumentation",
            to:
                "sensorsLab"
        )

        linkTheme(
            "openScience",
            to:
                "openScienceWG"
        )

        linkTheme(
            "international",
            to:
                "internationalSoftware"
        )

        linkTheme(
            "training",
            to:
                "seminarCommittee"
        )


        // ====================================================
        // MARK: Projects
        // ====================================================

        let projectSeeds:
            [DemoProjectSeed] =
            [
                DemoProjectSeed(
                    key: "oceansim",
                    theme: "rse",
                    secondaryTheme: "earth",
                    title: "Release OceanSim 2.4 research software",
                    summary: "Prepare a production release of the institute's coupled ocean-modelling library for international partners.",
                    status: .inProgress,
                    created: -18,
                    deadline: 8,
                    assignedPerson: "amina",
                    requestedBy: "nordicClimate",
                    partner: "internationalSoftware",
                    children: [
                        "Finalise public API compatibility tests",
                        "Complete CI matrix on Linux and macOS",
                        "Prepare release documentation and migration notes",
                    ],
                    noteTitle: "OceanSim release checklist",
                    noteBody: "Confirm DOI metadata, licence headers, changelog and reproducibility examples before tagging the release.",
                    eventTitle: "OceanSim code-review session",
                    eventBody: "Reviewed the numerical-core changes and agreed on the final release blockers."
                ),

                DemoProjectSeed(
                    key: "hpcMigration",
                    theme: "hpc",
                    secondaryTheme: "materials",
                    title: "Migrate molecular-dynamics workflows to the new HPC partition",
                    summary: "Move production molecular simulation workflows to the new GPU-enabled research-computing partition.",
                    status: .inProgress,
                    created: -20,
                    deadline: 12,
                    assignedPerson: "noah",
                    requestedBy: "materialsLab",
                    partner: "molecularSim",
                    children: [
                        "Benchmark representative GPU workloads",
                        "Port scheduler templates to the new partition",
                        "Validate checkpoint and restart behaviour",
                    ],
                    noteTitle: "HPC migration performance baseline",
                    noteBody: "The 4-GPU benchmark is approximately 31% faster, but I/O contention remains visible during checkpoint bursts.",
                    eventTitle: "HPC migration technical review",
                    eventBody: "HPC operations and materials researchers reviewed benchmark results and migration risks."
                ),

                DemoProjectSeed(
                    key: "climatePortal",
                    theme: "dataInfra",
                    secondaryTheme: "earth",
                    title: "Deploy federated climate-data portal",
                    summary: "Deliver a shared data portal joining local simulations with datasets hosted by international climate partners.",
                    status: .inProgress,
                    created: -17,
                    deadline: 18,
                    assignedPerson: "lucas",
                    requestedBy: "nordicClimate",
                    partner: "dataSystems",
                    children: [
                        "Deploy metadata catalogue service",
                        "Configure object-storage replication",
                        "Run end-to-end partner access test",
                    ],
                    noteTitle: "Climate portal federation notes",
                    noteBody: "Partner metadata use two different vocabularies; map both to the shared discovery schema before publication.",
                    eventTitle: "Climate portal architecture meeting",
                    eventBody: "Agreed on authentication boundaries, catalogue harvesting and replica ownership."
                ),

                DemoProjectSeed(
                    key: "seismicTomography",
                    theme: "earth",
                    secondaryTheme: "hpc",
                    title: "Reprocess regional seismic tomography dataset",
                    summary: "Re-run the regional imaging workflow using the revised station catalogue and uncertainty model.",
                    status: .inProgress,
                    created: -21,
                    deadline: 5,
                    assignedPerson: "elena",
                    requestedBy: "earthDepartment",
                    partner: "pacificObservatory",
                    children: [
                        "Validate revised station metadata",
                        "Run tomography inversion ensemble",
                        "Generate uncertainty and resolution figures",
                    ],
                    noteTitle: "Tomography inversion note",
                    noteBody: "Three stations have timing corrections that must be applied before the final inversion ensemble.",
                    eventTitle: "Seismic imaging interpretation meeting",
                    eventBody: "Reviewed preliminary structure and identified two regions requiring additional resolution tests."
                ),

                DemoProjectSeed(
                    key: "exoplanet",
                    theme: "physics",
                    secondaryTheme: "rse",
                    title: "Benchmark exoplanet transit pipeline",
                    summary: "Evaluate the next-generation transit-analysis pipeline against a controlled archive of synthetic and observed light curves.",
                    status: .todo,
                    created: -8,
                    deadline: 20,
                    assignedPerson: "yuki",
                    requestedBy: "helios",
                    partner: "astroPipelines",
                    children: [
                        "Prepare benchmark light-curve collection",
                        "Run reproducibility comparison",
                        "Document performance and numerical differences",
                    ],
                    noteTitle: "Transit benchmark acceptance criteria",
                    noteBody: "Track detection sensitivity, runtime, numerical reproducibility and provenance completeness.",
                    eventTitle: "Astronomy pipeline planning discussion",
                    eventBody: "Defined benchmark scope and agreed which legacy pipeline version will be used as reference."
                ),

                DemoProjectSeed(
                    key: "genomics",
                    theme: "biology",
                    secondaryTheme: "rse",
                    title: "Containerise international genomics workflow",
                    summary: "Package and validate the consortium's variant-analysis workflow for reproducible execution across partner sites.",
                    status: .completed,
                    created: -22,
                    deadline: -3,
                    assignedPerson: "priya",
                    requestedBy: "atlasBio",
                    partner: "genomicsTeam",
                    children: [
                        "Pin reference databases and software versions",
                        "Build reproducible workflow container",
                        "Validate results at partner institute",
                    ],
                    noteTitle: "Genomics workflow provenance",
                    noteBody: "All reference database versions and checksums are now recorded in the workflow provenance manifest.",
                    eventTitle: "Genomics reproducibility review",
                    eventBody: "Partner institute reproduced the validation cohort with matching variant calls."
                ),

                DemoProjectSeed(
                    key: "catalyst",
                    theme: "materials",
                    secondaryTheme: "hpc",
                    title: "Validate catalyst-screening simulation campaign",
                    summary: "Check the reproducibility and scientific integrity of the large computational catalyst-screening campaign.",
                    status: .todo,
                    created: -10,
                    deadline: 26,
                    assignedPerson: "leila",
                    requestedBy: "materialsLab",
                    partner: "molecularSim",
                    children: [
                        "Audit simulation input catalogue",
                        "Re-run selected reference calculations",
                        "Prepare validation summary for collaborators",
                    ],
                    noteTitle: "Catalyst screening anomaly",
                    noteBody: "One batch used a different convergence threshold; isolate it before computing aggregate rankings.",
                    eventTitle: "Materials simulation triage",
                    eventBody: "Reviewed the anomalous calculation batch and assigned a targeted re-run."
                ),

                DemoProjectSeed(
                    key: "sensors",
                    theme: "instrumentation",
                    secondaryTheme: "earth",
                    title: "Calibrate autonomous environmental sensor nodes",
                    summary: "Prepare the next generation of low-power sensor nodes for an international field deployment.",
                    status: .inProgress,
                    created: -15,
                    deadline: 10,
                    assignedPerson: "kwame",
                    requestedBy: "pacificObservatory",
                    partner: "sensorsLab",
                    children: [
                        "Run laboratory calibration sequence",
                        "Validate acquisition firmware timing",
                        "Prepare field deployment configuration",
                    ],
                    noteTitle: "Sensor calibration observation",
                    noteBody: "Two pressure sensors show temperature-dependent drift above the acceptance threshold.",
                    eventTitle: "Field instrumentation readiness review",
                    eventBody: "Reviewed calibration results, firmware status and deployment logistics."
                ),

                DemoProjectSeed(
                    key: "fairSprint",
                    theme: "openScience",
                    secondaryTheme: "dataInfra",
                    title: "FAIR metadata implementation sprint",
                    summary: "Introduce a shared metadata profile across software, datasets and computational workflows.",
                    status: .inProgress,
                    created: -14,
                    deadline: 15,
                    assignedPerson: "claire",
                    requestedBy: "meridian",
                    partner: "openScienceWG",
                    children: [
                        "Map existing repositories to the metadata profile",
                        "Add machine-readable software metadata",
                        "Prepare FAIR compliance examples",
                    ],
                    noteTitle: "Metadata interoperability decision",
                    noteBody: "Use persistent identifiers for people, software releases and datasets wherever available.",
                    eventTitle: "FAIR metadata working session",
                    eventBody: "Compared metadata requirements across Earth science, genomics and research software."
                ),

                DemoProjectSeed(
                    key: "workshop",
                    theme: "training",
                    secondaryTheme: "international",
                    title: "International reproducible-science workshop",
                    summary: "Organise a cross-disciplinary workshop for research software, reproducibility and scientific workflows.",
                    status: .todo,
                    created: -12,
                    deadline: 34,
                    assignedPerson: "maya",
                    requestedBy: "ersa",
                    partner: "seminarCommittee",
                    children: [
                        "Confirm invited instructors",
                        "Publish programme and registration page",
                        "Prepare hands-on computing environment",
                    ],
                    noteTitle: "Workshop programme ideas",
                    noteBody: "Include scientific Git workflows, reproducible environments, workflow provenance and FAIR software.",
                    eventTitle: "Workshop organising call",
                    eventBody: "Initial organising call with international partners and instructors."
                ),

                DemoProjectSeed(
                    key: "surrogateModels",
                    theme: "ai",
                    secondaryTheme: "earth",
                    title: "Train neural surrogate models for fluid simulations",
                    summary: "Evaluate scientific machine-learning surrogates for expensive environmental flow simulations.",
                    status: .inProgress,
                    created: -19,
                    deadline: 28,
                    assignedPerson: "samira",
                    requestedBy: "climateGroup",
                    partner: "hpcOps",
                    children: [
                        "Prepare training and validation dataset",
                        "Train baseline surrogate architecture",
                        "Compare physical and statistical error metrics",
                    ],
                    noteTitle: "Surrogate-model validation concern",
                    noteBody: "Validation must include physically distinct regimes rather than random train/test splitting alone.",
                    eventTitle: "Scientific ML methodology review",
                    eventBody: "Discussed validation design, uncertainty and interpretability with domain scientists."
                ),

                DemoProjectSeed(
                    key: "proposal",
                    theme: "international",
                    secondaryTheme: "rse",
                    title: "Submit cross-facility research software proposal",
                    summary: "Coordinate a multi-institution proposal for sustainable scientific software infrastructure.",
                    status: .closed,
                    created: -22,
                    deadline: -5,
                    assignedPerson: "sarah",
                    requestedBy: "ersa",
                    partner: "internationalSoftware",
                    children: [
                        "Collect partner work packages",
                        "Consolidate budget and effort estimates",
                        "Submit final consortium proposal",
                    ],
                    noteTitle: "Proposal submission record",
                    noteBody: "Final submission receipt and partner approvals were received and archived.",
                    eventTitle: "Final proposal sign-off",
                    eventBody: "All partners approved the final technical description and budget."
                ),

                DemoProjectSeed(
                    key: "storageExercise",
                    theme: "dataInfra",
                    secondaryTheme: "hpc",
                    title: "Quarterly storage resilience exercise",
                    summary: "Test recovery procedures for scientific storage and document service behaviour under controlled failure.",
                    status: .todo,
                    created: -6,
                    deadline: 31,
                    assignedPerson: "lucas",
                    requestedBy: "computingCentre",
                    partner: "alpineData",
                    children: [
                        "Select representative failure scenarios",
                        "Run controlled recovery exercise",
                        "Document recovery time and operational actions",
                    ],
                    noteTitle: "Storage exercise safeguards",
                    noteBody: "Use synthetic datasets only and confirm all production pools remain excluded from destructive tests.",
                    eventTitle: "Storage resilience planning meeting",
                    eventBody: "Defined safe test boundaries and agreed success criteria for the exercise."
                ),

                DemoProjectSeed(
                    key: "onboarding",
                    theme: "rse",
                    secondaryTheme: "openScience",
                    title: "Research software onboarding handbook",
                    summary: "Create a shared onboarding guide for scientists and engineers contributing to institute software.",
                    status: .completed,
                    created: -20,
                    deadline: -1,
                    assignedPerson: "ava",
                    requestedBy: "rseUnit",
                    partner: "openScienceWG",
                    children: [
                        "Document development environment setup",
                        "Add code-review and testing guidance",
                        "Publish contributor workflow examples",
                    ],
                    noteTitle: "Onboarding handbook feedback",
                    noteBody: "Early-career researchers asked for more examples of branching, review and reproducible environments.",
                    eventTitle: "Onboarding handbook review",
                    eventBody: "Research engineers and doctoral researchers reviewed the first complete handbook."
                ),

                DemoProjectSeed(
                    key: "visitorProgramme",
                    theme: "administration",
                    secondaryTheme: "international",
                    title: "Coordinate visiting-researcher programme",
                    summary: "Prepare upcoming international research visits spanning software, geophysics and computational biology.",
                    status: .todo,
                    created: -7,
                    deadline: 40,
                    assignedPerson: "maya",
                    requestedBy: "meridian",
                    partner: "seminarCommittee",
                    children: [
                        "Confirm visitor schedules and host groups",
                        "Prepare access and computing requirements",
                        "Coordinate seminars and scientific meetings",
                    ],
                    noteTitle: "Visitor computing requirements",
                    noteBody: "Two visitors require temporary HPC accounts and one needs access to the genomics workflow platform.",
                    eventTitle: "Visiting programme coordination meeting",
                    eventBody: "Hosts reviewed arrival dates, office space, seminars and computing access."
                ),

                DemoProjectSeed(
                    key: "visualisation",
                    theme: "rse",
                    secondaryTheme: "physics",
                    title: "Prototype interactive scientific visualisation dashboard",
                    summary: "Build a GPU-accelerated interactive viewer for large simulation and observation datasets.",
                    status: .inProgress,
                    created: -11,
                    deadline: 23,
                    assignedPerson: "mei",
                    requestedBy: "physicalSchool",
                    partner: "rseUnit",
                    children: [
                        "Benchmark large-volume rendering path",
                        "Implement linked spatial and temporal views",
                        "Run usability session with scientists",
                    ],
                    noteTitle: "Visualisation performance note",
                    noteBody: "Downsample only for interactive navigation; full-resolution values must remain available for inspection.",
                    eventTitle: "Scientific visualisation design review",
                    eventBody: "Domain scientists reviewed prototype interactions and data-volume constraints."
                ),
            ]


        for seed in projectSeeds {

            let started:
                Int?

            let completed:
                Int?


            switch seed.status {

            case .inProgress:
                started =
                    min(
                        -1,
                        seed.created + 2
                    )

                completed =
                    nil

            case .completed,
                 .closed:

                started =
                    seed.created + 1

                completed =
                    min(
                        -1,
                        seed.deadline
                        ?? -1
                    )

            case .todo:
                started =
                    nil

                completed =
                    nil
            }


            let root =
                addWork(
                    kind:
                        .task,
                    themeKeys:
                        [
                            seed.theme
                        ]
                        + (
                            seed.secondaryTheme
                                .map {
                                    [$0]
                                }
                            ?? []
                        ),
                    title:
                        seed.title,
                    body:
                        seed.summary,
                    status:
                        seed.status,
                    created:
                        seed.created,
                    deadline:
                        seed.deadline,
                    started:
                        started,
                    completed:
                        completed,
                    actorMembershipID:
                        administratorMembership.id
                )


            projects[seed.key] =
                root


            for
                (
                    index,
                    childTitle
                )
                in seed.children
                    .enumerated()
            {
                let childStatus:
                    TaskStatus

                let childStarted:
                    Int?

                let childCompleted:
                    Int?


                switch seed.status {

                case .completed,
                     .closed:

                    childStatus =
                        .completed

                    childStarted =
                        seed.created
                        + index
                        + 1

                    childCompleted =
                        min(
                            -1,
                            seed.created
                            + index
                            + 4
                        )

                case .inProgress:

                    if index == 0 {

                        childStatus =
                            .completed

                        childStarted =
                            seed.created
                            + 1

                        childCompleted =
                            min(
                                -2,
                                seed.created + 5
                            )

                    } else if index == 1 {

                        childStatus =
                            .inProgress

                        childStarted =
                            min(
                                -1,
                                seed.created + 6
                            )

                        childCompleted =
                            nil

                    } else {

                        childStatus =
                            .todo

                        childStarted =
                            nil

                        childCompleted =
                            nil
                    }

                case .todo:

                    childStatus =
                        .todo

                    childStarted =
                        nil

                    childCompleted =
                        nil
                }


                _ =
                    addWork(
                        kind:
                            .task,
                        themeKeys:
                            [
                                seed.theme
                            ],
                        title:
                            childTitle,
                        body:
                            "Demo sub-task belonging to \(seed.title).",
                        parent:
                            root,
                        status:
                            childStatus,
                        created:
                            min(
                                -1,
                                seed.created
                                + index
                                + 1
                            ),
                        deadline:
                            seed.deadline
                                .map {
                                    max(
                                        0,
                                        $0
                                        - (
                                            3
                                            - index
                                        )
                                    )
                                },
                        started:
                            childStarted,
                        completed:
                            childCompleted,
                        actorMembershipID:
                            administratorMembership.id
                    )
            }


            _ =
                addWork(
                    kind:
                        .note,
                    themeKeys:
                        [
                            seed.theme
                        ],
                    title:
                        seed.noteTitle,
                    body:
                        seed.noteBody,
                    parent:
                        root,
                    created:
                        min(
                            -1,
                            seed.created + 3
                        ),
                    reminder:
                        seed.status == .todo
                        ? 4
                        : nil,
                    logged:
                        min(
                            -1,
                            seed.created + 4
                        ),
                    actorMembershipID:
                        administratorMembership.id
                )


            _ =
                addWork(
                    kind:
                        .activity,
                    themeKeys:
                        [
                            seed.theme
                        ],
                    title:
                        seed.eventTitle,
                    body:
                        seed.eventBody,
                    parent:
                        root,
                    created:
                        min(
                            -2,
                            seed.created + 4
                        ),
                    logged:
                        min(
                            -1,
                            seed.created + 5
                        ),
                    actorMembershipID:
                        administratorMembership.id
                )


            addRelationship(
                workItemID:
                    root,
                entityKey:
                    seed.assignedPerson,
                role:
                    .assignedTo,
                inherited:
                    true
            )

            addRelationship(
                workItemID:
                    root,
                entityKey:
                    seed.requestedBy,
                role:
                    .requestedBy,
                inherited:
                    true
            )

            addRelationship(
                workItemID:
                    root,
                entityKey:
                    seed.partner,
                role:
                    .with,
                inherited:
                    true
            )

            addRelationship(
                workItemID:
                    root,
                entityKey:
                    "meridian",
                role:
                    .forWhom,
                inherited:
                    true
            )

            addRelationship(
                workItemID:
                    root,
                entityKey:
                    seed.partner,
                role:
                    .relatedTo,
                inherited:
                    false
            )
        }


        // ====================================================
        // MARK: Calendar
        // ====================================================

        var researchCalendar =
            TestudoCalendar(
                name:
                    "Research & Collaboration"
            )

        researchCalendar.timeZoneID =
            timeZoneID

        researchCalendar.isEnabled =
            true

        researchCalendar.isReadOnly =
            false

        researchCalendar.createdAt =
            clock.date(
                -22,
                hour:
                    9
            )

        researchCalendar.updatedAt =
            clock.date(
                -1,
                hour:
                    16
            )


        data.calendars.append(
            researchCalendar
        )


        let calendarSeeds:
            [DemoCalendarSeed] =
            [
                DemoCalendarSeed(
                    title: "Research Software Engineering weekly sync",
                    businessDay: -18,
                    hour: 10,
                    durationMinutes: 45,
                    location: "CRC Meeting Room 2 / Video",
                    theme: "rse",
                    project: "oceansim",
                    attendees: ["amina", "ava", "mei"]
                ),

                DemoCalendarSeed(
                    title: "Seismic imaging interpretation meeting",
                    businessDay: -14,
                    hour: 14,
                    durationMinutes: 60,
                    location: "Earth Sciences Seminar Room",
                    theme: "earth",
                    project: "seismicTomography",
                    attendees: ["elena", "sofia", "ana"]
                ),

                DemoCalendarSeed(
                    title: "Genomics reproducibility review",
                    businessDay: -10,
                    hour: 11,
                    durationMinutes: 60,
                    location: "ICLS / Video",
                    theme: "biology",
                    project: "genomics",
                    attendees: ["priya", "hana"]
                ),

                DemoCalendarSeed(
                    title: "HPC migration benchmark review",
                    businessDay: -7,
                    hour: 15,
                    durationMinutes: 60,
                    location: "CRC Operations Room",
                    theme: "hpc",
                    project: "hpcMigration",
                    attendees: ["noah", "ravi", "linh"]
                ),

                DemoCalendarSeed(
                    title: "Open Science & FAIR working group",
                    businessDay: -4,
                    hour: 13,
                    durationMinutes: 75,
                    location: "Library Collaboration Space",
                    theme: "openScience",
                    project: "fairSprint",
                    attendees: ["claire", "omar", "ines"]
                ),

                DemoCalendarSeed(
                    title: "International software consortium architecture call",
                    businessDay: -1,
                    hour: 11,
                    durationMinutes: 60,
                    location: "Video conference",
                    theme: "international",
                    project: "oceansim",
                    attendees: ["amina", "sarah", "ava"]
                ),

                DemoCalendarSeed(
                    title: "Research computing planning meeting",
                    businessDay: 1,
                    hour: 9,
                    durationMinutes: 60,
                    location: "CRC Board Room",
                    theme: "dataInfra",
                    project: "storageExercise",
                    attendees: ["lucas", "noah", "ravi"]
                ),

                DemoCalendarSeed(
                    title: "Climate portal partner review",
                    businessDay: 3,
                    hour: 14,
                    durationMinutes: 60,
                    location: "Video conference",
                    theme: "earth",
                    project: "climatePortal",
                    attendees: ["mateo", "erik", "ines"]
                ),

                DemoCalendarSeed(
                    title: "Scientific Machine Learning methodology seminar",
                    businessDay: 5,
                    hour: 11,
                    durationMinutes: 60,
                    location: "Main Auditorium",
                    theme: "ai",
                    project: "surrogateModels",
                    attendees: ["samira", "mateo", "ravi"]
                ),

                DemoCalendarSeed(
                    title: "Environmental sensor readiness review",
                    businessDay: 7,
                    hour: 10,
                    durationMinutes: 75,
                    location: "Instrumentation Laboratory",
                    theme: "instrumentation",
                    project: "sensors",
                    attendees: ["kwame", "fatima", "camila"]
                ),

                DemoCalendarSeed(
                    title: "Exoplanet pipeline benchmark kickoff",
                    businessDay: 10,
                    hour: 15,
                    durationMinutes: 60,
                    location: "QPC Data Lab / Video",
                    theme: "physics",
                    project: "exoplanet",
                    attendees: ["yuki", "diego", "mei"]
                ),

                DemoCalendarSeed(
                    title: "Research software release readiness review",
                    businessDay: 12,
                    hour: 14,
                    durationMinutes: 60,
                    location: "CRC Meeting Room 1",
                    theme: "rse",
                    project: "oceansim",
                    attendees: ["amina", "ava", "sarah"]
                ),

                DemoCalendarSeed(
                    title: "Catalyst screening validation meeting",
                    businessDay: 15,
                    hour: 10,
                    durationMinutes: 60,
                    location: "Advanced Materials Laboratory",
                    theme: "materials",
                    project: "catalyst",
                    attendees: ["leila", "linh", "noah"]
                ),

                DemoCalendarSeed(
                    title: "Visiting planetary scientist seminar",
                    businessDay: 18,
                    hour: 14,
                    durationMinutes: 90,
                    location: "Main Seminar Room",
                    theme: "training",
                    project: "visitorProgramme",
                    attendees: ["kenji", "elena", "maya"]
                ),

                DemoCalendarSeed(
                    title: "Scientific visualisation usability session",
                    businessDay: 20,
                    hour: 13,
                    durationMinutes: 90,
                    location: "Visualisation Suite",
                    theme: "rse",
                    project: "visualisation",
                    attendees: ["mei", "diego", "camila"]
                ),

                DemoCalendarSeed(
                    title: "International FAIR metadata interoperability call",
                    businessDay: 24,
                    hour: 11,
                    durationMinutes: 60,
                    location: "Video conference",
                    theme: "openScience",
                    project: "fairSprint",
                    attendees: ["claire", "omar", "priya"]
                ),

                DemoCalendarSeed(
                    title: "Storage resilience exercise",
                    businessDay: 29,
                    hour: 9,
                    durationMinutes: 180,
                    location: "CRC Operations Room",
                    theme: "dataInfra",
                    project: "storageExercise",
                    attendees: ["lucas", "noah", "ines"]
                ),

                DemoCalendarSeed(
                    title: "International reproducible-science workshop",
                    businessDay: 34,
                    hour: 9,
                    durationMinutes: 420,
                    location: "Innovation Centre",
                    theme: "training",
                    project: "workshop",
                    attendees: ["maya", "claire", "amina", "priya"]
                ),

                DemoCalendarSeed(
                    title: "Research software sustainability forum",
                    businessDay: 38,
                    hour: 13,
                    durationMinutes: 180,
                    location: "European Research Software Alliance / Video",
                    theme: "international",
                    project: "onboarding",
                    attendees: ["sarah", "ava", "amina"]
                ),

                DemoCalendarSeed(
                    title: "Cross-disciplinary science programme review",
                    businessDay: 44,
                    hour: 10,
                    durationMinutes: 120,
                    location: "Meridian Council Room",
                    theme: "international",
                    project: "visitorProgramme",
                    attendees: ["maya", "elena", "samira", "priya", "yuki"]
                ),
            ]


        for seed in calendarSeeds {

            let start =
                clock.date(
                    seed.businessDay,
                    hour:
                        seed.hour
                )

            let end =
                Calendar
                    .current
                    .date(
                        byAdding:
                            .minute,
                        value:
                            seed.durationMinutes,
                        to:
                            start
                    )
                ?? start


            var event =
                CalendarEvent(
                    title:
                        seed.title,
                    startAt:
                        start,
                    endAt:
                        end
                )

            event.calendarID =
                researchCalendar.id

            event.notes =
                "Generated Testudo Demo calendar event."

            event.location =
                seed.location

            event.startTimeZoneID =
                timeZoneID

            event.endTimeZoneID =
                timeZoneID

            event.organizerName =
                adminDisplayName.isEmpty
                ? "Testudo User"
                : adminDisplayName

            event.organizerEmail =
                localProfile
                    .professionalEmail
                    .isEmpty
                ? nil
                : localProfile
                    .professionalEmail

            event.attendeeEmails =
                seed.attendees
                    .compactMap {
                        peopleEmails[$0]
                    }
                    .filter {
                        !$0.isEmpty
                    }

            event.createdAt =
                clock.date(
                    -20,
                    hour:
                        10
                )

            event.updatedAt =
                clock.date(
                    -1,
                    hour:
                        16
                )


            data.calendarEvents.append(
                event
            )


            if
                let themeID =
                    themes[
                        seed.theme
                    ]
            {
                data
                    .calendarEventThemeLinks
                    .append(
                        CalendarEventThemeLink(
                            calendarEventID:
                                event.id,
                            themeID:
                                themeID
                        )
                    )
            }


            if
                let projectKey =
                    seed.project,
                let workItemID =
                    projects[
                        projectKey
                    ]
            {
                data
                    .calendarEventWorkLinks
                    .append(
                        CalendarEventWorkLink(
                            calendarEventID:
                                event.id,
                            workItemID:
                                workItemID
                        )
                    )
            }
        }


        return
            DemoEnvironmentPayload(
                data:
                    data,
                administratorMembershipID:
                    administratorMembership.id,
                rangeStart:
                    rangeStart,
                rangeEnd:
                    rangeEnd
            )
    }
}
