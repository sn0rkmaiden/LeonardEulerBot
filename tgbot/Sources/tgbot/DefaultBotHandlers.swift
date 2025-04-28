//
//  DefaultBotHandlers.swift
//  tgbot
//
//  Created by Emir Byashimov on 02.04.2025.
//

import Foundation
import SwiftTelegramSdk
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class DefaultBotHandlers {
    
    static var awaitingFileUsers: Set<Int64> = []
    
    static func addHandlers(bot: TGBot) async {
        print("Adding bot handlers...")
        await messageHandler(bot: bot)
        await commandPingHandler(bot: bot)
        await commandShowButtonsHandler(bot: bot)
        await buttonsActionHandler(bot: bot)
        await commandUploadFileHandler(bot: bot)
        await documentHandler(bot: bot)
    }
    
    private static func commandUploadFileHandler(bot: TGBot) async {
        print("Setting up /upload_file command handler...")
        await bot.dispatcher.add(TGCommandHandler(commands: ["/upload_file"]) { update in
            guard let userId = update.message?.from?.id else {
                print("User ID not found for /upload_file")
                return
            }
            
            awaitingFileUsers.insert(userId)
            
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Отправьте файл для загрузки.")
            do {
                try await bot.sendMessage(params: params)
                print("Message sent to user \(userId): 'Отправьте файл для загрузки.'")
            } catch {
                print("Error sending message to user \(userId): \(error.localizedDescription)")
            }
        })
    }
    
    private static func documentHandler(bot: TGBot) async {
        print("Setting up document handler...")
        await bot.dispatcher.add(TGMessageHandler(filters: .document) { update in
            guard let userId = update.message?.from?.id, awaitingFileUsers.contains(userId),
                  let document = update.message?.document else {
                print("No valid document received or user not awaiting file.")
                return
            }
            
            awaitingFileUsers.remove(userId)
            
            let fileId = document.fileId
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Файл получен! Идет обработка...")
            do {
                try await bot.sendMessage(params: params)
                print("Message sent to user \(userId): 'Файл получен! Идет обработка...'")
            } catch {
                print("Error sending message to user \(userId): \(error.localizedDescription)")
            }
            
            await processFile(fileId: fileId, bot: bot, chatId: userId)
        })
    }
    
    private static func processFile(fileId: String, bot: TGBot, chatId: Int64) async {
        print("Processing file with ID: \(fileId)...")
        
        do {
            let fileParams = TGGetFileParams(fileId: fileId)
            let file = try await bot.getFile(params: fileParams)
            
            guard let filePath = file.filePath, !filePath.isEmpty else {
                print("Ошибка: filePath отсутствует или пустой")
                let errorMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Ошибка: файл не найден на сервере Telegram. Пожалуйста, отправьте файл заново.")
                try? await bot.sendMessage(params: errorMessage)
                return
            }
            
            // Строим полный URL
            guard let telegramApiToken = ProcessInfo.processInfo.environment["TELEGRAM_BOT_API"], !telegramApiToken.isEmpty else {
                print("Ошибка: TELEGRAM_BOT_API токен не найден в окружении")
                let errorMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Ошибка настройки бота. Попробуйте позже.")
                try? await bot.sendMessage(params: errorMessage)
                return
            }
            
            let telegramFileURL = "https://api.telegram.org/file/bot\(telegramApiToken)/\(filePath)"
            print("Downloading file from URL: \(telegramFileURL)")
            
            let savePath = "/home/LeonardEulerBot/tgbot/documents/\(UUID().uuidString).pdf"
            
            // Пытаемся скачать файл
            do {
                try await downloadFile(from: telegramFileURL, to: savePath)
                print("File successfully downloaded and saved to: \(savePath)")
            } catch {
                print("Ошибка при загрузке файла: \(error.localizedDescription)")
                let errorMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Не удалось скачать файл. Попробуйте отправить файл заново.")
                try? await bot.sendMessage(params: errorMessage)
                return
            }
            
            // Теперь читаем файл и отправляем обратно пользователю
            do {
                let fileData = try Data(contentsOf: URL(fileURLWithPath: savePath))
                print("File data read successfully.")
                
                let inputFile = TGInputFile(filename: "respondFile.pdf", data: fileData, mimeType: "application/pdf")
                let fileInfo = TGFileInfo.file(inputFile)
                
                let sendParams = TGSendDocumentParams(
                    chatId: .chat(chatId),
                    document: fileInfo,
                    caption: "Файл успешно загружен и отправлен"
                )
                
                try await bot.sendDocument(params: sendParams)
                print("File successfully sent to user \(chatId).")
                
            } catch {
                print("Ошибка при чтении или отправке файла: \(error.localizedDescription)")
                let errorMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Ошибка при обработке файла. Попробуйте позже.")
                try? await bot.sendMessage(params: errorMessage)
            }
            
        } catch {
            print("Ошибка при получении filePath через getFile: \(error.localizedDescription)")
            let errorMessage = TGSendMessageParams(chatId: .chat(chatId), text: "Ошибка при получении данных о файле.")
            try? await bot.sendMessage(params: errorMessage)
        }
    }

    
    private static func downloadFile(from url: String, to path: String) async throws {
        print("Downloading file from URL: \(url) to path: \(path)...")
        
        guard let fileURL = URL(string: url) else {
            throw NSError(domain: "TGFileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Некорректный URL для скачивания файла"])
        }

        let request = URLRequest(url: fileURL)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TGFileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Некорректный ответ сервера при загрузке файла"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "TGFileError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Файл не найден на сервере Telegram (код ответа: \(httpResponse.statusCode))"])
        }
        
        try data.write(to: URL(fileURLWithPath: path))
        print("File successfully downloaded to: \(path)")
    }


    private static func messageHandler(bot: TGBot) async {
        print("Setting up message handler...")
        await bot.dispatcher.add(TGMessageHandler(filters: (.all && !.command.names(["/ping", "/show_buttons"]))) { update in
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: "Success")
            try await bot.sendMessage(params: params)
            print("Message sent: 'Success'")
        })
    }
    
    private static func commandPingHandler(bot: TGBot) async {
        print("Setting up /ping command handler...")
        await bot.dispatcher.add(TGCommandHandler(commands: ["/ping"]) { update in
            try await update.message?.reply(text: "pong", bot: bot)
            print("/ping command received, 'pong' sent.")
        })
    }
    
    private static func commandShowButtonsHandler(bot: TGBot) async {
        print("Setting up /show_buttons command handler...")
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
            print("/show_buttons command received, buttons sent to user \(userId).")
        })
    }
    
    private static func buttonsActionHandler(bot: TGBot) async {
        print("Setting up buttons action handler...")
        await bot.dispatcher.add(TGCallbackQueryHandler(pattern: "press 1") { update in
            print("Button 1 pressed.")
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
            print("Button 2 pressed.")
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
