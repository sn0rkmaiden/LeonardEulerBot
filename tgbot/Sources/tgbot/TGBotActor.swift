//
//  TGBotActor.swift
//  tgbot
//
//  Created by Emir Byashimov on 02.04.2025.
//

import SwiftTelegramSdk

actor TGBotActor {
    private var _bot: TGBot!

    var bot: TGBot {
        self._bot
    }
    
    func setBot(_ bot: TGBot) {
        self._bot = bot
    }
}
