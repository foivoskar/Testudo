import Foundation


// ============================================================
// MARK: - Local Profile → Environment Person import
//
// Import is deliberately COPY-ONLY.
//
// LocalUserProfile remains application-local.
// PersonProfile remains Environment-local.
//
// There is no live synchronization between the two.
// ============================================================

enum LocalProfileImportSection:
    String,
    CaseIterable,
    Identifiable
{
    case identity =
        "Identity"

    case professional =
        "Professional Information"

    case contact =
        "Contact"

    case onlineIdentity =
        "Online & Research Identity"

    case location =
        "Location"

    case additional =
        "Additional Information"


    var id:
        String
    {
        rawValue
    }
}


enum LocalProfileImportField:
    String,
    CaseIterable,
    Identifiable,
    Hashable
{
    case avatar

    case firstName
    case middleName
    case lastName
    case preferredName
    case academicTitle
    case jobTitle

    case professionalEmail
    case secondaryProfessionalEmail
    case professionalPhone
    case secondaryPhone
    case office
    case employeeID
    case assistantContact

    case website
    case orcid
    case linkedIn
    case github
    case researcherID
    case scopusAuthorID
    case googleScholarURL

    case professionalAddress
    case city
    case postalCode
    case country

    case professionalFields
    case responsibilities
    case preferredLanguage
    case timeZone
    case tags
    case notes


    var id:
        String
    {
        rawValue
    }


    var label:
        String
    {
        switch self {

        case .avatar:
            return "Profile photo"

        case .firstName:
            return "First name"

        case .middleName:
            return "Middle name"

        case .lastName:
            return "Last name"

        case .preferredName:
            return "Preferred name"

        case .academicTitle:
            return "Academic title"

        case .jobTitle:
            return "Job title"

        case .professionalEmail:
            return "Professional email"

        case .secondaryProfessionalEmail:
            return "Secondary professional email"

        case .professionalPhone:
            return "Professional phone"

        case .secondaryPhone:
            return "Secondary phone"

        case .office:
            return "Office"

        case .employeeID:
            return "Employee ID"

        case .assistantContact:
            return "Assistant / contact"

        case .website:
            return "Website"

        case .orcid:
            return "ORCID"

        case .linkedIn:
            return "LinkedIn"

        case .github:
            return "GitHub"

        case .researcherID:
            return "Researcher ID"

        case .scopusAuthorID:
            return "Scopus Author ID"

        case .googleScholarURL:
            return "Google Scholar"

        case .professionalAddress:
            return "Professional address"

        case .city:
            return "City"

        case .postalCode:
            return "Postal code"

        case .country:
            return "Country"

        case .professionalFields:
            return "Professional fields"

        case .responsibilities:
            return "Responsibilities"

        case .preferredLanguage:
            return "Preferred language"

        case .timeZone:
            return "Time zone"

        case .tags:
            return "Tags"

        case .notes:
            return "Notes"
        }
    }


    var section:
        LocalProfileImportSection
    {
        switch self {

        case .avatar,
             .firstName,
             .middleName,
             .lastName,
             .preferredName:
            return .identity


        case .academicTitle,
             .jobTitle,
             .office,
             .employeeID:
            return .professional


        case .professionalEmail,
             .secondaryProfessionalEmail,
             .professionalPhone,
             .secondaryPhone,
             .assistantContact:
            return .contact


        case .website,
             .orcid,
             .linkedIn,
             .github,
             .researcherID,
             .scopusAuthorID,
             .googleScholarURL:
            return .onlineIdentity


        case .professionalAddress,
             .city,
             .postalCode,
             .country:
            return .location


        case .professionalFields,
             .responsibilities,
             .preferredLanguage,
             .timeZone,
             .tags,
             .notes:
            return .additional
        }
    }


    func displayValue(
        from profile:
            LocalUserProfile
    ) -> String {

        switch self {

        case .avatar:
            return
                profile.avatarData == nil
                ? ""
                : "Profile photo"


        case .firstName:
            return profile.firstName

        case .middleName:
            return profile.middleName

        case .lastName:
            return profile.lastName

        case .preferredName:
            return profile.preferredName

        case .academicTitle:
            return profile.academicTitle ?? ""

        case .jobTitle:
            return profile.jobTitle

        case .professionalEmail:
            return profile.professionalEmail

        case .secondaryProfessionalEmail:
            return profile.secondaryProfessionalEmail

        case .professionalPhone:
            return profile.professionalPhone

        case .secondaryPhone:
            return profile.secondaryPhone ?? ""

        case .office:
            return profile.office

        case .employeeID:
            return profile.employeeID

        case .assistantContact:
            return profile.assistantContact ?? ""

        case .website:
            return profile.website

        case .orcid:
            return profile.orcid

        case .linkedIn:
            return profile.linkedIn

        case .github:
            return profile.github

        case .researcherID:
            return profile.researcherID ?? ""

        case .scopusAuthorID:
            return profile.scopusAuthorID ?? ""

        case .googleScholarURL:
            return profile.googleScholarURL ?? ""

        case .professionalAddress:
            return profile.professionalAddress ?? ""

        case .city:
            return profile.city ?? ""

        case .postalCode:
            return profile.postalCode ?? ""

        case .country:
            return profile.country ?? ""

        case .professionalFields:
            return profile.professionalFields

        case .responsibilities:
            return profile.responsibilities

        case .preferredLanguage:
            return profile.preferredLanguage ?? ""

        case .timeZone:
            return profile.timeZone ?? ""

        case .tags:
            return profile.tags ?? ""

        case .notes:
            return profile.notes
        }
    }


    func hasValue(
        in profile:
            LocalUserProfile
    ) -> Bool {

        !displayValue(
            from:
                profile
        )
        .trimmingCharacters(
            in:
                .whitespacesAndNewlines
        )
        .isEmpty
    }
}
