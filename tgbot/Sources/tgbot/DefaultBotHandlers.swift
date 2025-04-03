//
//  DefaultBotHandlers.swift
//  tgbot
//
//  Created by Emir Byashimov on 02.04.2025.
//

import Foundation
import SwiftTelegramSdk

final class DefaultBotHandlers {
    
    static var awaitingFileUsers: Set<Int64> = []
    
    static func addHandlers(bot: TGBot) async {
        await messageHandler(bot: bot)
        await commandPingHandler(bot: bot)
        await commandShowButtonsHandler(bot: bot)
        await buttonsActionHandler(bot: bot)
        await commandUploadFileHandler(bot: bot)
        await documentHandler(bot: bot)
    }
    
    private static func commandUploadFileHandler(bot: TGBot) async {
        await bot.dispatcher.add(TGCommandHandler(commands: ["/upload_file"]) { update in
            guard let userId = update.message?.from?.id else { return }
            
            awaitingFileUsers.insert(userId)
            
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Отправьте файл для загрузки.")
            try await bot.sendMessage(params: params)
        })
    }
    
    private static func documentHandler(bot: TGBot) async {
        await bot.dispatcher.add(TGMessageHandler(filters: .document) { update in
            guard let userId = update.message?.from?.id, awaitingFileUsers.contains(userId),
                  let document = update.message?.document else {
                return
            }
            
            awaitingFileUsers.remove(userId)
            
            let fileId = document.fileId
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Файл получен! Идет обработка...")
            try await bot.sendMessage(params: params)
            
            await processFile(fileId: fileId, bot: bot, chatId: userId)
        })
    }
    
    private static func processFile(fileId: String, bot: TGBot, chatId: Int64) async {
        do {
            let fileParams = TGGetFileParams(fileId: fileId)
            let file = try await bot.getFile(params: fileParams)
            
            guard let filePath = file.filePath else {
                throw NSError(domain: "TGFileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Файл не найден"])
            }
            
            let telegramFileURL = "https://api.telegram.org/file/bot\(ProcessInfo.processInfo.environment["TELEGRAM_BOT_API"] ?? "")/\(filePath)"
            print(telegramFileURL)
            let savePath = "/root/LeonardEulerBot/tgbot/documents/\(UUID().uuidString).pdf"
            
            try await downloadFile(from: telegramFileURL, to: savePath)
            
            let successMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Файл сохранен: \(savePath)")
            try await bot.sendMessage(params: successMessage)
            
        } catch {
            print("Ошибка при обработке файла: \(error.localizedDescription)")
            let errorMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Ошибка обработки файла.")
            try? await bot.sendMessage(params: errorMessage)
        }
    }
    
    private static func downloadFile(from url: String, to path: String) async throws {
        guard let fileURL = URL(string: url) else {
            throw NSError(domain: "TGFileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Некорректный URL"])
        }

        let request = URLRequest(url: fileURL)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "TGFileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Ошибка загрузки файла"])
        }

        try data.write(to: URL(fileURLWithPath: path))
    }

    
    private static func messageHandler(bot: TGBot) async {
        await bot.dispatcher.add(TGMessageHandler(filters: (.all && !.command.names(["/ping", "/show_buttons"]))) { update in
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: "Success")
            try await bot.sendMessage(params: params)
        })
    }
    
    private static func commandPingHandler(bot: TGBot) async {
        await bot.dispatcher.add(TGCommandHandler(commands: ["/ping"]) { update in
            try await update.message?.reply(text: "pong", bot: bot)
        })
    }
    
    private static func commandShowButtonsHandler(bot: TGBot) async {
        await bot.dispatcher.add(TGCommandHandler(commands: ["/show_buttons"]) { update in
            guard let userId = update.message?.from?.id else { fatalError("user id not found") }
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Button 1", callbackData: "press 1"), .init(text: "Button 2", callbackData: "press 2")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Keyboard active",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
        })
    }
    
    private static func buttonsActionHandler(bot: TGBot) async {
        await bot.dispatcher.add(TGCallbackQueryHandler(pattern: "press 1") { update in
            TGBot.log.info("press 1")
            guard let userId = update.callbackQuery?.from.id else { fatalError("user id not found") }
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: update.callbackQuery?.data  ?? "data not exist",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
            try await bot.sendMessage(params: .init(chatId: .chat(userId), text: "press 1"))
        })
        
        await bot.dispatcher.add(TGCallbackQueryHandler(pattern: "press 2") { update in
            TGBot.log.info("press 2")
            guard let userId = update.callbackQuery?.from.id else { fatalError("user id not found") }
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: update.callbackQuery?.data  ?? "data not exist",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
            try await bot.sendMessage(params: .init(chatId: .chat(userId), text: "press 2"))
        })
    }
}
