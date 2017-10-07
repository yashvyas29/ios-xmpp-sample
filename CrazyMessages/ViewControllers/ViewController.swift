//
//  ViewController.swift
//  CrazyMessages
//
//  Created by Andres on 7/21/16.
//  Copyright © 2016 Andres. All rights reserved.
//

import UIKit
import XMPPFramework

class ViewController: UIViewController {

    @IBOutlet weak var txtVwSendMessage: UITextView!
    @IBOutlet weak var lblReceivedMessage: UILabel!
    
    weak var logInViewController: LogInViewController?
    var logInPresented = false
    var xmppController: XMPPController!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !self.logInPresented {
            self.logInPresented = true
            self.performSegue(withIdentifier: "LogInViewController", sender: nil)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "LogInViewController" {
            let viewController = segue.destination as! LogInViewController
            viewController.delegate = self
        }
    }
    
    @IBAction func sendAction(_ sender: UIButton) {
        xmppController.send(txtVwSendMessage.text, toUser: xmppController.userJID.full())
    }
    
    @IBAction func logoutAction(_ sender: UIButton) {
        xmppController.disconnect()
        xmppController = nil
        if logInViewController == nil {
            logInViewController = self.storyboard?.instantiateViewController(withIdentifier: "LogInViewController") as? LogInViewController
        }
        if logInViewController != nil {
            self.present(logInViewController!, animated: true, completion: nil)
        }
    }
}

extension ViewController: LogInViewControllerDelegate {

    func didTouchLogIn(sender: LogInViewController, userJID: String, userPassword: String, server: String) {
        self.logInViewController = sender

        do {
            try self.xmppController = XMPPController(hostName: server,
                                                     userJIDString: userJID,
                                                     password: userPassword)
            self.xmppController.xmppStream.addDelegate(self, delegateQueue: DispatchQueue.main)
            self.xmppController.connect()
        } catch {
            sender.showErrorMessage(message: "Something went wrong")
        }
    }
}

extension ViewController: XMPPStreamDelegate {

    func xmppStreamDidAuthenticate(_ sender: XMPPStream!) {
        self.logInViewController?.dismiss(animated: true, completion: nil)
    }
    
    func xmppStream(_ sender: XMPPStream!, didNotAuthenticate error: DDXMLElement!) {
        self.logInViewController?.showErrorMessage(message: "Wrong password or username")
    }
    
    func xmppStream(_ sender: XMPPStream!, didReceive message: XMPPMessage!) {
        lblReceivedMessage.text = message.body()
    }
    
}

