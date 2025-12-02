import SharedTypes "../shared_types";
import Const "./const";
import List "mo:base/List";
import Map "mo:map/Map";
import  { phash } "mo:map/Map";

module {

  public type NotificationStore = {
    notifications : Map.Map<Principal, List.List<Notification>>;
    limitPerUser: Nat; // Cantidad limite de notificaciones por usuario
    storageTimeLimit: Int;  // Tiempo limite de guardado de notificaciones:
  };

  public type NID = Int;

  public type KeyValue = SharedTypes.MetadataPart;

  let reactions = [
    "👍","👎","👏","🙏","✊","🙌","❤️","🤝","💯","⚖️","📜","😂","😢","🔥","😍","🤔","😎","🎉","🤯","😏",
    "🕊️","🌍","🫶","😮","👀","😡","📢","🌱","🧑‍🤝‍🧑","🤗","💬","🕯️","🏳️","🤝🏽","🤝","🚀","😭","🤩","💔","🫶",
  ];

  public func getReactions() : [Text] {
    reactions;
  };

  public type NotificationContext = {
    root : Int; // ID del elemento principal (Ej: Proposal Id, Post Id, etc.)
    path : [Int]; // Ruta jerárquica hasta el subelemento específico (Ej: comentario, subcomentario ID)
    senderName : Text;
    sender : Principal;
  };

  public type NotificationKind = {
    #ReactComment : NotificationContext and {
      reaction : Nat8; // La reaccion se especifica con el indice del array reactions
    };
    #CommentReply : NotificationContext and {
      msg : Text;
    };
    #NewMention : NotificationContext and {
      msg : Text;
    };
    #System: KeyValue;
    #GenericNotification : KeyValue;
  };

  public type Notification = {
    date : NID; // Notification Id is the timestamp
    kind : NotificationKind;
    resume : Text;
    to : Principal;
    read : Bool;
  };

  /// Funciones 

  public func init(): NotificationStore {
    {
      notifications = Map.new<Principal, List.List<Notification>>();
      limitPerUser = 20;
      storageTimeLimit =  Const.NANOSECONDS_PER_DAY * 90;
    }
  };

  public func pushNotification(store: NotificationStore, notification: Notification, to: Principal) {
    let currentNotifications = switch (Map.get<Principal, List.List<Notification>>(store.notifications, phash, to)) {
      case null { List.nil<Notification>() };
      case ( ?previous ) previous;
    };
    let notifications = List.push<Notification>(notification, currentNotifications ); //TODO investigar por qué ya no esta deprecated
    ignore Map.put<Principal, List.List<Notification>>(store.notifications, phash, to, notifications);
  };

  public func batchNotification(store: NotificationStore, notification: Notification, toAll: [Principal]) {
    for (to in toAll.vals()){
      pushNotification(store, notification, to);
    }
  };

  public func getNotificationsFor(store:  NotificationStore, p: Principal): List.List<Notification> {
    switch (Map.get<Principal, List.List<Notification>>(store.notifications, phash, p)) {
      case null null;
      case ( ?n ) { n } 
    }
  };

  public func markAsRead(store:  NotificationStore, p: Principal, date: NID): {#Ok; #Err: Text}{
    let notificationsUpdate = List.map<Notification, Notification>(
      getNotificationsFor(store, p), 
      func n = if(n.date == date){ {n with read = true}} else {n}
    );
    ignore Map.put<Principal, List.List<Notification>>(store.notifications, phash, p, notificationsUpdate);
    return #Ok
  };

  public func deleteNotification(store: NotificationStore, p: Principal, date: NID): { #Ok; #Err: Text } {
    let notificationsUpdate = List.filter<Notification>(
      getNotificationsFor(store, p), 
      func n = n.date != date
    );
    ignore Map.put<Principal, List.List<Notification>>(store.notifications, phash, p, notificationsUpdate);
    return #Ok
  };
};
