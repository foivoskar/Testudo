import Foundation


// ============================================================
// MARK: - Persisted recovery question
//
// Question text is intentionally stored in plaintext so it can
// be shown during recovery.
//
// The answer itself is NEVER stored. Only a salted PBKDF-style
// hash produced by PasswordHasher is persisted.
// ============================================================

struct SecurityQuestionCredential:
    Codable,
    Hashable,
    Identifiable
{
    var id:
        UUID

    var question:
        String

    var answerSaltBase64:
        String

    var answerHashBase64:
        String

    var answerIterations:
        Int

    var createdAt:
        Date

    var updatedAt:
        Date
}


// ============================================================
// MARK: - Public display prompt
// ============================================================

struct SecurityQuestionPrompt:
    Identifiable,
    Hashable
{
    var id:
        UUID

    var question:
        String
}


// ============================================================
// MARK: - Ephemeral editor draft
//
// This type is intentionally NOT Codable.
// Plain answers exist only in memory while the user is editing.
// ============================================================

struct SecurityQuestionDraft:
    Hashable
{
    var question:
        String = ""

    var answer:
        String = ""


    static var emptySet:
        [SecurityQuestionDraft]
    {
        [
            SecurityQuestionDraft(),
            SecurityQuestionDraft(),
            SecurityQuestionDraft(),
        ]
    }
}


// ============================================================
// MARK: - Recovery validation
// ============================================================

enum SecurityRecoveryError:
    LocalizedError
{
    case exactlyThreeQuestions
    case missingQuestion
    case missingAnswer
    case duplicateQuestion
    case answerTooShort
    case hashingFailed


    var errorDescription:
        String?
    {
        switch self {

        case .exactlyThreeQuestions:
            return
                "Exactly three security questions are required."

        case .missingQuestion:
            return
                "Each security question must contain a question."

        case .missingAnswer:
            return
                "Each security question must contain an answer."

        case .duplicateQuestion:
            return
                "The three security questions must be different."

        case .answerTooShort:
            return
                "Each security answer must contain at least 3 characters."

        case .hashingFailed:
            return
                "The security answers could not be secured."
        }
    }
}


// ============================================================
// MARK: - Security recovery helper
// ============================================================

enum SecurityRecovery {

    static func prompts(
        from credentials:
            [SecurityQuestionCredential]?
    ) -> [SecurityQuestionPrompt] {

        credentials?
            .map {
                SecurityQuestionPrompt(
                    id:
                        $0.id,
                    question:
                        $0.question
                )
            }
        ?? []
    }


    static func createCredentials(
        from drafts:
            [SecurityQuestionDraft]
    ) throws -> [SecurityQuestionCredential] {

        guard
            drafts.count
                == 3
        else {
            throw
                SecurityRecoveryError
                    .exactlyThreeQuestions
        }


        let cleaned =
            drafts
                .map {
                    SecurityQuestionDraft(
                        question:
                            $0.question
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                ),
                        answer:
                            normalizedAnswer(
                                $0.answer
                            )
                    )
                }


        guard
            cleaned
                .allSatisfy({
                    !$0.question.isEmpty
                })
        else {
            throw
                SecurityRecoveryError
                    .missingQuestion
        }


        guard
            cleaned
                .allSatisfy({
                    !$0.answer.isEmpty
                })
        else {
            throw
                SecurityRecoveryError
                    .missingAnswer
        }


        guard
            cleaned
                .allSatisfy({
                    $0.answer.count
                        >= 3
                })
        else {
            throw
                SecurityRecoveryError
                    .answerTooShort
        }


        let normalizedQuestions =
            cleaned
                .map {
                    $0.question
                        .folding(
                            options:
                                [
                                    .caseInsensitive,
                                    .diacriticInsensitive,
                                ],
                            locale:
                                Locale(
                                    identifier:
                                        "en_US_POSIX"
                                )
                        )
                }


        guard
            Set(
                normalizedQuestions
            )
            .count
                == 3
        else {
            throw
                SecurityRecoveryError
                    .duplicateQuestion
        }


        let now =
            Date()


        do {

            return
                try cleaned
                    .map {
                        draft in

                        let hash =
                            try PasswordHasher
                                .createHash(
                                    password:
                                        draft.answer
                                )


                        return
                            SecurityQuestionCredential(
                                id:
                                    UUID(),
                                question:
                                    draft.question,
                                answerSaltBase64:
                                    hash.saltBase64,
                                answerHashBase64:
                                    hash.hashBase64,
                                answerIterations:
                                    hash.iterations,
                                createdAt:
                                    now,
                                updatedAt:
                                    now
                            )
                    }

        } catch {

            throw
                SecurityRecoveryError
                    .hashingFailed
        }
    }


    static func verify(
        answer:
            String,
        against credential:
            SecurityQuestionCredential
    ) -> Bool {

        let normalized =
            normalizedAnswer(
                answer
            )


        guard
            !normalized.isEmpty
        else {
            return false
        }


        return
            PasswordHasher
                .verify(
                    password:
                        normalized,
                    saltBase64:
                        credential
                            .answerSaltBase64,
                    expectedHashBase64:
                        credential
                            .answerHashBase64,
                    iterations:
                        credential
                            .answerIterations
                )
    }


    static func normalizedAnswer(
        _ raw:
            String
    ) -> String {

        let trimmed =
            raw
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        let folded =
            trimmed
                .folding(
                    options:
                        [
                            .caseInsensitive,
                            .diacriticInsensitive,
                            .widthInsensitive,
                        ],
                    locale:
                        Locale(
                            identifier:
                                "en_US_POSIX"
                        )
                )


        return
            folded
                .split(
                    whereSeparator:
                        \.isWhitespace
                )
                .joined(
                    separator:
                        " "
                )
    }
}
