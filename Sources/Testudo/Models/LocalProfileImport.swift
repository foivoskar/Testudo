import Foundation


// ============================================================
// MARK: - Application Profile ↔ Environment Person copy
//
// Profile transfer is deliberately EXPLICIT and COPY-ONLY.
//
// LocalUserProfile remains application-local.
// PersonProfile remains Environment-local.
//
// Values may be copied in either direction at the user's request,
// but there is no live synchronization between the two.
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


// ============================================================
// MARK: - Environment Person → Local Application Profile
//
// These overloads use the exact same field vocabulary as the
// existing Local Profile → Environment Person import.
//
// Copying remains explicit and one-time.
// ============================================================

extension LocalProfileImportField {

    func displayValue(
        from profile:
            PersonProfile
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
            PersonProfile
    ) -> Bool {

        if
            self == .avatar
        {
            return
                profile.avatarData
                    != nil
        }


        return
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


    func copyValue(
        from source:
            PersonProfile,
        to target:
            inout LocalUserProfile
    ) {

        switch self {

        case .avatar:
            target.avatarData =
                source.avatarData

        case .firstName:
            target.firstName =
                source.firstName

        case .middleName:
            target.middleName =
                source.middleName

        case .lastName:
            target.lastName =
                source.lastName

        case .preferredName:
            target.preferredName =
                source.preferredName

        case .academicTitle:
            target.academicTitle =
                source.academicTitle

        case .jobTitle:
            target.jobTitle =
                source.jobTitle

        case .professionalEmail:
            target.professionalEmail =
                source.professionalEmail

        case .secondaryProfessionalEmail:
            target.secondaryProfessionalEmail =
                source.secondaryProfessionalEmail

        case .professionalPhone:
            target.professionalPhone =
                source.professionalPhone

        case .secondaryPhone:
            target.secondaryPhone =
                source.secondaryPhone

        case .office:
            target.office =
                source.office

        case .employeeID:
            target.employeeID =
                source.employeeID

        case .assistantContact:
            target.assistantContact =
                source.assistantContact

        case .website:
            target.website =
                source.website

        case .orcid:
            target.orcid =
                source.orcid

        case .linkedIn:
            target.linkedIn =
                source.linkedIn

        case .github:
            target.github =
                source.github

        case .researcherID:
            target.researcherID =
                source.researcherID

        case .scopusAuthorID:
            target.scopusAuthorID =
                source.scopusAuthorID

        case .googleScholarURL:
            target.googleScholarURL =
                source.googleScholarURL

        case .professionalAddress:
            target.professionalAddress =
                source.professionalAddress

        case .city:
            target.city =
                source.city

        case .postalCode:
            target.postalCode =
                source.postalCode

        case .country:
            target.country =
                source.country

        case .professionalFields:
            target.professionalFields =
                source.professionalFields

        case .responsibilities:
            target.responsibilities =
                source.responsibilities

        case .preferredLanguage:
            target.preferredLanguage =
                source.preferredLanguage

        case .timeZone:
            target.timeZone =
                source.timeZone

        case .tags:
            target.tags =
                source.tags

        case .notes:
            target.notes =
                source.notes
        }
    }
}
