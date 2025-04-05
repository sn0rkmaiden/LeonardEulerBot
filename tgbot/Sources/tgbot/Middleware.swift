//
//  Middleware.swift
//  tgbot
//
//  Created by Emir Byashimov on 05.04.2025.
//

import Vapor

final class FileScanBlockerMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let suspicious = ["zip", "php", "bak", "db", "admin"]
        
        if suspicious.contains(where: { request.url.string.contains($0) }) {
            request.logger.warning("Blocked suspicious request: \(request.url.string)")
            throw Abort(.notFound)
        }

        return try await next.respond(to: request)
    }
}
