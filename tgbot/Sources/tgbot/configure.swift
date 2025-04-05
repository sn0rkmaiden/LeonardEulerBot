import Foundation
import Vapor
import SwiftTelegramSdk

// configures your application
public func configure(_ app: Application) async throws {
    let botActor: TGBotActor = .init()
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 80
    // register routes
    let tgApi = ProcessInfo.processInfo.environment["TELEGRAM_BOT_API"] ?? ""
    let bot: TGBot = try await .init(connectionType: .longpolling(limit: nil,
                                                                  timeout: nil,
                                                                  allowedUpdates: nil),
                                     dispatcher: nil,
                                     tgClient: VaporTGClient(client: app.client),
                                     tgURI: TGBot.standardTGURL,
                                     botId: tgApi,
                                     log: app.logger)
        await botActor.setBot(bot)
        await DefaultBotHandlers.addHandlers(bot: botActor.bot)
        try await botActor.bot.start()
    
    try routes(app)
}
