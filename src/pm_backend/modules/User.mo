import Map "mo:map/Map";
import Set "mo:map/Set";
import { phash } "mo:map/Map";
import Principal "mo:base/Principal";
import { now } "mo:base/Time";

module {

  public type Metadata = [MeatadataPart];

  public type MeatadataPart = {
    key : Text;
    value : Value;
  };

  public type Value = {
    #Nat : Nat;
    #Int : Int;
    #Blob : Blob;
    #Text : Text;
    #Array : [Value];
    #Map : [(Text, Value)];
  };

  public type Verification = {
    #Email;
    #Phone;
    #Custom : MeatadataPart;
  };

  public type EditableData = {
    name : Text;
    email : ?Text;
    bio : Text;
    avatar : ?Blob;
    thumbnail : ?Blob;
    metadata : [Metadata];
  };

  public type User = EditableData and {
    principal : Principal;
    scoring : Nat;
    lastActivity : Int;
    verifications : [Verification];
  };

  public type SignUpResponse = { #Ok : User; #Err : User };
  public type LoginResponse = { #Ok : User; #Err : Text };

  public type State = {
    users : Map.Map<Principal, User>;
    admins : Set.Set<Principal>;
  };

  public func init() : State {
    {
      users = Map.new<Principal, User>();
      admins = Set.new<Principal>();
    };
  };

  public func signUp(s : State, caller : Principal, name : Text) : SignUpResponse {
    switch (Map.get<Principal, User>(s.users, phash, caller)) {
      case null {
        let newUser : User = {
          avatar = null;
          bio = "";
          email = null;
          metadata = [];
          name;
          principal = caller;
          thumbnail = null;
          lastActivity = now();
          scoring : Nat = 0;
          verifications = [];
        };
        ignore Map.put<Principal, User>(s.users, phash, caller, newUser);
        #Ok(newUser);
      };
      case (?user) { #Err(user) };
    };
  };

  public func login(s : State, caller : Principal) : LoginResponse {
    switch (Map.get<Principal, User>(s.users, phash, caller)) {
      case (?user) {
        #Ok(user);
      };
      case null { #Err("UserNotFound") };
    };
  };

  public func isAdmin(s : State, caller : Principal) : Bool {
    Set.has<Principal>(s.admins, phash, caller);
  };

  public func getUser(s : State, p : Principal) : ?User {
    Map.get<Principal, User>(s.users, phash, p);
  };

  public func isUser(s : State, p : Principal) : Bool {
    Map.has<Principal, User>(s.users, phash, p);
  };

};
