import Types "./types";
import List "mo:base/List";
import Map "mo:map/Map";
import { phash } "mo:map/Map";
import Const "./const";
import { print } "mo:base/Debug"; 

module {

  // Types

  public type NotificationStore = Types.NotificationStore;
  public type Notification = Types.Notification;
  public type NID = Types.NID;

  /// Funciones

  public func init() : NotificationStore {
    {
      notifications = Map.new<Principal, List.List<Notification>>();
      limitPerUser = 30;
      storageTimeLimit = Const.NANOSECONDS_PER_DAY * 90;
    };
  };

  public func getReactions() : [Text] {
    Const.REACTIONS;
  };


  public func pushNotification(store : NotificationStore, notification : Notification, to : Principal) {
    let currentNotifications = switch (Map.get<Principal, List.List<Notification>>(store.notifications, phash, to)) {
      case null { List.nil<Notification>() };
      case (?previous) previous;
    };
    let notifications = List.push<Notification>(notification, currentNotifications); //TODO investigar por qué ya no esta deprecated
    ignore Map.put<Principal, List.List<Notification>>(store.notifications, phash, to, notifications);
  };

  public func batchNotification(store : NotificationStore, notification : Notification, toAll : [Principal]) {
    for (to in toAll.vals()) {
      pushNotification(store, notification, to);
    };
  };

  public func getNotificationsFor(store : NotificationStore, p : Principal) : List.List<Notification> {
    switch (Map.get<Principal, List.List<Notification>>(store.notifications, phash, p)) {
      case null null;
      case (?n) { n };
    };
  };

  public func markAsRead(store : NotificationStore, p : Principal, date : NID) : {
    #Ok;
    #Err : Text;
  } {
    let notificationsUpdate = List.map<Notification, Notification>(
      getNotificationsFor(store, p),
      func n = if (n.date == date) { print("Hola"); { n with read = true } } else { n },
    );
    ignore Map.put<Principal, List.List<Notification>>(store.notifications, phash, p, notificationsUpdate);
    return #Ok;
  };

  public func deleteNotification(store : NotificationStore, p : Principal, date : NID) : {
    #Ok;
    #Err : Text;
  } {
    let notificationsUpdate = List.filter<Notification>(
      getNotificationsFor(store, p),
      func n = n.date != date,
    );
    ignore Map.put<Principal, List.List<Notification>>(store.notifications, phash, p, notificationsUpdate);
    return #Ok;
  };

};
