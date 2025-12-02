import Map "mo:map/Map";
import Set "mo:map/Set";
import { phash } "mo:map/Map";
import Principal "mo:base/Principal";
import { now } "mo:base/Time";
import SharedTypes "./shared_types";

module {

  public type Metadata = [MetadataPart];

  public type MetadataPart = SharedTypes.MetadataPart;

  public type Value = SharedTypes.Value;

  public type Verification = {
    #Email;
    #Phone;
    #Custom : MetadataPart;
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

  public func init(admin: Principal) : State {
    {
      users = Map.new<Principal, User>();
      admins = Set.make<Principal>(phash, admin);
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
