// Card Tray Demo
// Copyright (C) 2016  Sasmito Adibowo – http://cutecoder.org

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


import UIKit

open class CardListModel: NSObject {
    
    public override init() {
        
    }
    
    open lazy fileprivate(set) var cardListURL : URL = {
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cardDir = appSupportDir.appendingPathComponent("CardTray", isDirectory: true)
        do {
            try fileManager.createDirectory(at: cardDir, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            
        }
        let cardFile = cardDir.appendingPathComponent("cards.plist", isDirectory: false)
        return cardFile
    }()

    fileprivate(set) var loaded = false
    
    fileprivate(set) var dirty = false
    
    @objc fileprivate(set) open var cards : Array<CardEntity>?
    
    static func automaticallyNotifiesObserversForCards() -> Bool {
        return true
    }
    
    open func moveToFront(_ index : Int) {
        guard cards != nil else {
            return
        }
        let card = cards![index]
        cards!.remove(at: index)
        cards!.append(card)
        dirty = true
    }
    
    open func add(_ card: CardEntity) {
        if cards == nil {
            cards = Array<CardEntity>()
            cards?.reserveCapacity(6)
        }
        cards?.append(card)
        dirty = true
    }
    
    open func remove(_ cardToRemove:CardEntity?) -> Int? {
        if let  card = cardToRemove,
                let index = cards?.index(of: card) {
            cards?.remove(at: index)
            dirty = true
            return index
        }
        return nil
    }
    
    
    
    open func load(_ completionHandler: ((NSError?)->Void)? ) {
        let targetURL = self.cardListURL
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive).async {
            var returnError : NSError?
            var resultArray : Array<CardEntity>?
            defer {
                DispatchQueue.main.async(execute: {
                    if returnError == nil && resultArray != nil {
                        // TODO: raise KVO?
                        self.cards = resultArray
                        self.loaded = true
                        self.dirty = false
                    }
                    
                    completionHandler?(returnError)
                })
            }
            do {
                let data = try Data(contentsOf: targetURL, options: [.mappedIfSafe,.uncached])
                if let array = NSKeyedUnarchiver.unarchiveObject(with: data) as? Array<CardEntity> {
                    resultArray = array
                }
            } catch let error as NSError {
                returnError = error
            }
        }
    }
    
    open func save(_ completionHandler: ((NSError?)->Void)? ) {
        guard dirty else {
            // not dirty.
            completionHandler?(nil)
            return
        }
        guard let cards = self.cards else {
            // todo: create error?
            completionHandler?(nil)
            return
        }
        let archivedData = NSKeyedArchiver.archivedData(withRootObject: cards)
        let targetURL = self.cardListURL
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
            var returnError : NSError?
            defer {
                DispatchQueue.main.async(execute: {
                    if returnError == nil {
                        self.dirty = false
                    }
                    completionHandler?(returnError)
                })
            }
            do {
                try archivedData.write(to: targetURL, options: [.atomic,.completeFileProtection])
                // In addition to passcode lock, we need to also prevent iTunes from creating a backup of the
                // card tray data. If the user doesn't set a passcode to those backups, then they are stored in the clear,
                // making it possible for malicious applications on the desktop to extract credit card numbers.
                try (targetURL as NSURL).setResourceValue(NSNumber(value: true as Bool), forKey: URLResourceKey.isExcludedFromBackupKey)
            } catch let error as NSError {
                returnError = error
            }
        }
    }
}
