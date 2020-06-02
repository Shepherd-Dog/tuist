import Foundation
import TuistSupport
import TSCBasic

enum CertificateParserError: FatalError, Equatable {
    case nameParsingFailed(AbsolutePath, String)
    case developmentTeamParsingFailed(AbsolutePath, String)
    
    var type: ErrorType {
        switch self {
        case .nameParsingFailed, .developmentTeamParsingFailed:
            return .abort
        }
    }
    
    var description: String {
        switch self {
        case let .nameParsingFailed(path, input):
            return "We couldn't parse the development team while parsing the following output from the file \(path.pathString): \(input)"
        case let .developmentTeamParsingFailed(path, input):
            return "We couldn't parse the development team while parsing the following output from the file \(path.pathString): \(input)"
        }
    }
}

protocol CertificateParsing {
    func parse(publicKey: AbsolutePath, privateKey: AbsolutePath) throws -> Certificate
}

final class CertificateParser: CertificateParsing {
    func parse(publicKey: AbsolutePath, privateKey: AbsolutePath) throws -> Certificate {
        let subject = try self.subject(at: publicKey)
        let isRevoked = subject.contains("REVOKED")
        
        let nameRegex = try NSRegularExpression(pattern: "CN=([^/]+)/", options: [])
        guard
            let result = nameRegex.firstMatch(in: subject, options: [], range: NSRange(location: 0, length: subject.count))
            else { throw CertificateParserError.nameParsingFailed(publicKey, subject) }
        let name = NSString(string: subject).substring(with: result.range(at: 1)).spm_chomp()
        
        let developmentTeamRegex = try NSRegularExpression(pattern: "OU=([^/]+)/", options: [])
        guard
            let developmentTeamResult = developmentTeamRegex.firstMatch(in: subject, options: [], range: NSRange(location: 0, length: subject.count))
        else { throw CertificateParserError.developmentTeamParsingFailed(publicKey, subject) }
        let developmentTeam = NSString(string: subject).substring(with: developmentTeamResult.range(at: 1)).spm_chomp()
        
        return Certificate(publicKey: publicKey,
                           privateKey: privateKey,
                           developmentTeam: developmentTeam,
                           name: name,
                           isRevoked: isRevoked)
    }
    
    // MARK: - Helpers
    
    private func subject(at path: AbsolutePath) throws -> String {
        try System.shared.capture("openssl", "x509", "-inform", "der", "-in", path.pathString, "-noout", "-subject")
    }
}