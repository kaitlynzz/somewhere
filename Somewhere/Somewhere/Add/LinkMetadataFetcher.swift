//
//  LinkMetadataFetcher.swift
//  Somewhere — Add (Karan)
//
//  Karan: fetches a page and hands the HTML to LinkMetadataParser.
//
//  Deliberately dumb: it downloads bytes, checks they look like a web page,
//  and stops. All the judgement lives in the parser, which is testable.
//  Timeouts and a byte cap keep a slow or enormous page from hanging the
//  sheet or eating memory.
//
//  App target only.
//

import Foundation
import UIKit

enum LinkMetadataFetcher {

    enum FetchError: LocalizedError, Equatable {
        case unreachable(String)
        case notAWebPage
        case nothingUseful

        var errorDescription: String? {
            switch self {
            case .unreachable(let reason): "Couldn't open that link. \(reason)"
            case .notAWebPage:             "That link isn't a web page I can read."
            case .nothingUseful:           "That page didn't say much about itself — add the details yourself."
            }
        }
    }

    /// og: tags live in <head>; there's no reason to parse a whole catalogue page.
    private static let maxHTMLBytes = 600_000
    private static let maxImageBytes = 5_000_000

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            // Several shops only put og: tags in the desktop page.
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "en-US,en;q=0.9",
        ]
        return URLSession(configuration: configuration)
    }()

    // MARK: - Page

    static func metadata(for url: URL) async throws -> LinkMetadata {
        let (data, response) = try await load(url)

        if let mime = response.mimeType?.lowercased(), !mime.contains("html"), !mime.contains("xml") {
            throw FetchError.notAWebPage
        }

        let slice = data.count > maxHTMLBytes ? data.prefix(maxHTMLBytes) : data[...]
        let html = String(decoding: slice, as: UTF8.self)

        // Parse against the URL we actually landed on, so relative image
        // paths resolve correctly after a redirect.
        let metadata = LinkMetadataParser.parse(html: html, baseURL: response.url ?? url)
        guard !metadata.isEmpty else { throw FetchError.nothingUseful }
        return metadata
    }

    // MARK: - Preview image

    /// Never throws: a missing preview image is a cosmetic problem, not a failure.
    static func previewImage(at url: URL) async -> UIImage? {
        guard let (data, response) = try? await load(url) else { return nil }
        guard data.count <= maxImageBytes else { return nil }
        if let mime = response.mimeType?.lowercased(), !mime.hasPrefix("image") { return nil }
        return UIImage(data: data)
    }

    // MARK: - Transport

    private static func load(_ url: URL) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
                throw FetchError.unreachable("The site answered \(http.statusCode).")
            }
            return (data, response)
        } catch let error as FetchError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut:               throw FetchError.unreachable("It took too long to answer.")
            case .notConnectedToInternet: throw FetchError.unreachable("You're offline.")
            case .cannotFindHost, .cannotConnectToHost:
                                          throw FetchError.unreachable("That site didn't answer.")
            default:                      throw FetchError.unreachable(error.localizedDescription)
            }
        } catch {
            throw FetchError.unreachable(error.localizedDescription)
        }
    }
}
