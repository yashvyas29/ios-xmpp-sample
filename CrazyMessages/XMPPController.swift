//
//  XMPPController.swift
//  CrazyMessages
//
//  Created by Andres on 7/21/16.
//  Copyright © 2016 Andres. All rights reserved.
//

import Foundation
import XMPPFramework

enum XMPPControllerError: Error {
	case wrongUserJID
}

class XMPPController: NSObject {
	var xmppStream: XMPPStream
    var xmppReconnect: XMPPReconnect
    var xmppMessageArchivingCoreDataStorage: XMPPMessageArchivingCoreDataStorage
    var xmppMessageArchiving: XMPPMessageArchiving
	
	let hostName: String
	let userJID: XMPPJID
	let hostPort: UInt16
	let password: String
	
	init(hostName: String, userJIDString: String, hostPort: UInt16 = 5222, password: String) throws {
        guard let userJID = XMPPJID(string: userJIDString) else {
			throw XMPPControllerError.wrongUserJID
		}
		
		self.hostName = hostName
		self.userJID = userJID
		self.hostPort = hostPort
		self.password = password
		
		// Stream Configuration
		self.xmppStream = XMPPStream()
		self.xmppStream.hostName = hostName
		self.xmppStream.hostPort = hostPort
		self.xmppStream.startTLSPolicy = XMPPStreamStartTLSPolicy.allowed
		self.xmppStream.myJID = userJID
		
        self.xmppReconnect = XMPPReconnect()
        self.xmppReconnect.activate(self.xmppStream)
        
        self.xmppMessageArchivingCoreDataStorage = XMPPMessageArchivingCoreDataStorage()
        self.xmppMessageArchiving = XMPPMessageArchiving(messageArchivingStorage: self.xmppMessageArchivingCoreDataStorage)
        self.xmppMessageArchiving.clientSideMessageArchivingOnly = false
        self.xmppMessageArchiving.activate(self.xmppStream)
        
		super.init()
		
        self.xmppStream.addDelegate(self, delegateQueue: DispatchQueue.main)
        //self.xmppReconnect.addDelegate(self, delegateQueue: .main)
        //self.xmppMessageArchiving.addDelegate(self, delegateQueue: .main)
	}
	
	func connect() {
		if !self.xmppStream.isDisconnected() {
			return
		}

        try! self.xmppStream.connect(withTimeout: XMPPStreamTimeoutNone)
	}
    
    func disconnect() {
        if !self.xmppStream.isDisconnected() {
            xmppStream.disconnect()
            xmppStream.removeDelegate(self)
            
            xmppReconnect.deactivate()
            //xmppReconnect.removeDelegate(self)
            
            xmppMessageArchiving.deactivate()
            //xmppMessageArchiving.removeDelegate(self)
        }
    }
    
    func send(_ message: String, toUser: String) {
        let xmppMessage = XMPPMessage(type: "chat", to: XMPPJID(string: toUser))
        xmppMessage?.addBody(message)
        xmppStream.send(xmppMessage)
        
        /*
        let messageElement = DDXMLElement(name: "message")
        messageElement.addAttribute(withName: "type", stringValue: "chat")
        messageElement.addAttribute(withName: "to", stringValue: toUser)
        messageElement.addAttribute(withName: "from", stringValue: userJID.full())
        let bodyElement = DDXMLElement(name: "body", stringValue: message)
        messageElement.addChild(bodyElement)
        xmppStream.send(messageElement)
         */
    }
    
    func getLocalArchivedMessages(withUser: String? = nil) -> [XMPPMessageArchiving_Message_CoreDataObject]? {
        if let messageMOC = xmppMessageArchivingCoreDataStorage.mainThreadManagedObjectContext {
            let messageFR = XMPPMessageArchiving_Message_CoreDataObject.fetchRequest()
            if withUser != nil, !withUser!.isEmpty {
                messageFR.predicate = NSPredicate(format: "bareJidStr = %@ || streamBareJidStr = %@", userJID.full(), withUser!)
            }
            do {
                return try messageMOC.fetch(messageFR) as? [XMPPMessageArchiving_Message_CoreDataObject]
            } catch let error {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    func getRemoteArchieveMessages() {
        guard let iQ = DDXMLElement.element(withName: "iq") as? DDXMLElement else {
            return
        }
        iQ.addAttribute(withName: "type", stringValue: "get")
        //iQ.addAttribute(withName: "id", stringValue: "page1")
        let list = DDXMLElement.element(withName: "retrieve") as! DDXMLElement
        list.addAttribute(withName: "xmlns", stringValue: "urn:xmpp:archive")
        list.addAttribute(withName: "with", stringValue: userJID.full())
        let set = DDXMLElement.element(withName: "set") as! DDXMLElement
        set.addAttribute(withName: "xmlns", stringValue: "http://jabber.org/protocol/rsm")
        let max = DDXMLElement.element(withName: "max", stringValue: "30") as! DDXMLElement
        //max.addAttribute(withName: "xmlns", stringValue: "http://jabber.org/protocol/rsm")
        set.addChild(max)
        list.addChild(set)
        iQ.addChild(list)
        xmppStream.send(iQ)
    }
}

extension XMPPController: XMPPStreamDelegate {
	
	func xmppStreamDidConnect(_ stream: XMPPStream!) {
		print("Stream: Connected")
		try! stream.authenticate(withPassword: self.password)
	}
	
	func xmppStreamDidAuthenticate(_ sender: XMPPStream!) {
		self.xmppStream.send(XMPPPresence())
		print("Stream: Authenticated")
	}
	
	func xmppStream(_ sender: XMPPStream!, didNotAuthenticate error: DDXMLElement!) {
		print("Stream: Fail to Authenticate")
	}
    
    func xmppStreamDidDisconnect(_ sender: XMPPStream!, withError error: Error!) {
        print("Stream: Disconnected")
    }
    
    func xmppStream(_ sender: XMPPStream!, didReceiveError error: DDXMLElement!) {
        print("Stream: Error")
    }
    
    func xmppStream(_ sender: XMPPStream!, didFailToSend message: XMPPMessage!, error: Error!) {
        print("Stream: Failed to sned message.\n\(error.localizedDescription)")
    }
}

extension XMPPController: XMPPReconnectDelegate {
    func xmppReconnect(_ sender: XMPPReconnect!, shouldAttemptAutoReconnect connectionFlags: SCNetworkConnectionFlags) -> Bool {
        return true
    }
    func xmppReconnect(_ sender: XMPPReconnect!, didDetectAccidentalDisconnect connectionFlags: SCNetworkConnectionFlags) {
        print("Reconnect: Detected accidental disconnect")
    }
}
