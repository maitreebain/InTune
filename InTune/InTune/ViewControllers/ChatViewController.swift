//
//  ChatViewController.swift
//  InTune
//
//  Created by Oscar Victoria Gonzalez  on 6/1/20.
//  Copyright © 2020 Tiffany Obi. All rights reserved.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import Firebase
import FirebaseFirestore

class ChatViewController: MessagesViewController, InputBarAccessoryViewDelegate, MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {

//   var currentUser: User = Auth.auth().currentUser!
    
    var currentUser: Artist?
    
    
    
//    var user2Name: String?
    var user2ImgUrl: String?
//    var user2UID: String?
    
    var artist: Artist?
    
    private let databaseService = DatabaseService()
    
    private var docReference: DocumentReference?
    
    var messages: [Message] = []
    
    private var chatsCollection = "chats"
       
       override func viewDidLoad() {
            super.viewDidLoad()
        updateCurrentArtist()
        self.title = artist?.name

            navigationItem.largeTitleDisplayMode = .never
            maintainPositionOnKeyboardFrameChanged = true
            messageInputBar.inputTextView.tintColor = .primary
            messageInputBar.sendButton.setTitleColor(.primary, for: .normal)
            
            messageInputBar.delegate = self
            messagesCollectionView.messagesDataSource = self
            messagesCollectionView.messagesLayoutDelegate = self
            messagesCollectionView.messagesDisplayDelegate = self
            
            loadChat()

            
        }
    
    func updateCurrentArtist() {
        guard let currentUser = Auth.auth().currentUser else {return}
        databaseService.fetchArtist(userID: currentUser.uid) { (result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let artist):
                self.currentUser = artist
            }
        }
    }
    
    func addToThread() {
        databaseService.createThread(artist: artist!) { (result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success:
                print("succesfully updated database")
            }
        }
    }
    
    func addToThread2() {
        databaseService.createThread2(sender: artist!, artist: currentUser!) { (result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success:
                print("success")
            }
        }
    }
       
       
      func createNewChat() {
        let users = [self.currentUser?.artistId, self.artist?.artistId]
           let data: [String: Any] = [
               "users":users
           ]
           
           let db = Firestore.firestore().collection(chatsCollection)
           db.addDocument(data: data) { (error) in
               if let error = error {
                   print("Unable to create chat! \(error)")
                   return
               } else {
                   self.loadChat()
                   self.addToThread()
                   self.addToThread2()
               }
           }
      }
       
       func loadChat() {
              
              //Fetch all the chats which has current user in it
              let db = Firestore.firestore().collection(chatsCollection)
                      .whereField("users", arrayContains: Auth.auth().currentUser?.uid ?? "Not Found User 1")
              
              
              db.getDocuments { (chatQuerySnap, error) in
                  
                  if let error = error {
                      print("Error: \(error)")
                      return
                  } else {
                      
                      //Count the no. of documents returned
                      guard let queryCount = chatQuerySnap?.documents.count else {
                          return
                      }
                      
                      if queryCount == 0 {
                          //If documents count is zero that means there is no chat available and we need to create a new instance
                          self.createNewChat()
                      }
                      else if queryCount >= 1 {
                          //Chat(s) found for currentUser
                          for doc in chatQuerySnap!.documents {
                              
                              let chat = Chat(dictionary: doc.data())
                              //Get the chat which has user2 id
//                            if ((chat?.users.contains(self.artist?.artistId ?? ""))!) {
                            if chat?.users.contains(self.artist?.artistId ?? "") ?? false {
                                  
                                  self.docReference = doc.reference
                                  //fetch it's thread collection
                                   doc.reference.collection("thread")
                                      .order(by: "created", descending: false)
                                      .addSnapshotListener(includeMetadataChanges: true, listener: { (threadQuery, error) in
                                  if let error = error {
                                      print("Error: \(error)")
                                      return
                                  } else {
                                      self.messages.removeAll()
                                          for message in threadQuery!.documents {

                                              let msg = Message(dictionary: message.data())
                                              self.messages.append(msg!)
                                              print("Data: \(msg?.content ?? "No message found")")
                                          }
                                      self.messagesCollectionView.reloadData()
                                      self.messagesCollectionView.scrollToBottom(animated: true)
                                  }
                                  })
//                                  self.addToThread()
//                                  self.addToThread2()
                                  return
                              } //end of if
                          } //end of for
                          self.createNewChat()
                      } else {
                          print("Let's hope this error never prints!")
                      }
                  }
              }
          }
       
       private func insertNewMessage(_ message: Message) {
             
             messages.append(message)
             messagesCollectionView.reloadData()
             
             DispatchQueue.main.async {
                 self.messagesCollectionView.scrollToBottom(animated: true)
             }
         }
       
       private func save(_ message: Message) {
             
             let data: [String: Any] = [
                 "content": message.content,
                 "created": message.created,
                 "id": message.id,
                 "senderID": message.senderID,
                 "senderName": message.senderName
             ]
             
             docReference?.collection("thread").addDocument(data: data, completion: { (error) in
                 
                 if let error = error {
                     print("Error Sending message: \(error)")
                     return
                 }
                 
                 self.messagesCollectionView.scrollToBottom()
                 
             })
         }
       
       func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {

        let message = Message(id: UUID().uuidString, content: text, created: Timestamp(), senderID: currentUser!.artistId, senderName: (currentUser?.name)!)
                   
                     //messages.append(message)
                     insertNewMessage(message)
                     save(message)
       
                     inputBar.inputTextView.text = ""
                     messagesCollectionView.reloadData()
                     messagesCollectionView.scrollToBottom(animated: true)
               }
       
       
       func currentSender() -> SenderType {
        return Sender(senderId: Auth.auth().currentUser?.uid ?? "no user id", displayName: Auth.auth().currentUser?.displayName ?? "Name not found")
       }
       
       func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
           return messages[indexPath.section]
       }
       
       func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
           if messages.count == 0 {
                      print("No messages to display")
                      return 0
                  } else {
                      return messages.count
                  }
       }
       
        // MARK: - MessagesLayoutDelegate
           
           func avatarSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
               return .zero
           }
           
           // MARK: - MessagesDisplayDelegate
           func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
               return isFromCurrentSender(message: message) ? .blue: .lightGray
           }

   //        func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
   //
   //            if message.sender.senderId == currentUser.uid {
   //                SDWebImageManager.shared.loadImage(with: currentUser.photoURL, options: .highPriority, progress: nil) { (image, data, error, cacheType, isFinished, imageUrl) in
   //                    avatarView.image = image
   //                }
   //            } else {
   ////                SDWebImageManager.shared.loadImage(with: URL(string: user2ImgUrl!), options: .highPriority, progress: nil) { (image, data, error, cacheType, isFinished, imageUrl) in
   ////                    avatarView.image = image
   ////                }
   //            }
   //        }

           func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {

               let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight: .bottomLeft
               return .bubbleTail(corner, .curved)

           }
           
       }

   extension UIColor {
       static var primary: UIColor {
           return UIColor(red: 1 / 255, green: 93 / 255, blue: 48 / 255, alpha: 1)
       }
       
       static var incomingMessage: UIColor {
           return UIColor(red: 230 / 255, green: 230 / 255, blue: 230 / 255, alpha: 1)
       }
       
   }
    
