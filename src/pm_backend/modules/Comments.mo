import List "mo:base/List";
import Array "mo:base/Array";
import { now } "mo:base/Time";
import Principal "mo:base/Principal";

module {

  // ======== Types ========= //

  public type CommentBox = {
    depthLimit : Nat;
    comments : List.List<Comment>;
    size: Nat
  };

  public type PushResult = { #Ok : CommentBox; #Err : Text };
  public type DeleteResult = { #Ok : CommentBox; #Err : Text };
  public type EditResult = { #Ok : CommentBox; #Err : Text };
  public type ReactResult = { #Ok : CommentBox; #Err : Text };

  public type Comment = {
    created_at : Int;
    last_modification : ?Int;
    creator : Principal;
    msg : Text;
    likes : [Principal];
    dislikes : [Principal];
    subComments : List.List<Comment>;
  };

  func addIfNotInclude<T>(a : [T], e : T, equal : (T, T) -> Bool) : [T] {
    if (not inArray<T>(a, e, equal)) {
      Array.tabulate<T>(
        a.size() + 1,
        func i = if (i == 0) { e } else { a[i - 1 : Nat] },
      );
    } else {
      a;
    };
  };

  func inArray<T>(a : [T], e : T, equal : (T, T) -> Bool) : Bool {
    for (elem in a.vals()) {
      if (equal(elem, e)) { return true };
    };
    false;
  };


  func removeFromArray<T>(a: [T], e: T, equal: (T, T) -> Bool): [T] {
    Array.filter<T>(a, func u = not equal(u, e))
  };

  public func edit(box: CommentBox, path: [Int], newMsg: Text, caller: Principal): EditResult {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    let result = editFrom(box.comments, path, newMsg, caller);

    switch (result) {
      case (#Ok(comments)) {
        return #Ok({ box with comments; });
      };
      case (#Err(msg)) {
        return #Err(msg);
      };
    };
  };

  func editFrom(list: List.List<Comment>, path: [Int], newMsg: Text, caller: Principal): { #Ok : List.List<Comment>; #Err : Text } {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    var result = List.nil<Comment>();
    var found = false;

    for (comment in List.toIter(List.reverse(list))) {
      if (comment.created_at == path[0] and not found) {
        found := true;
        if (path.size() == 1) {
          if (caller == comment.creator) {
            let editedComment = {
              comment with
              msg = newMsg;
              last_modification = ?now();
            };
            result := List.push<Comment>(editedComment, result);
          } else {
            return #Err("Access denied");
          };
        } else {
          let subPath = Array.subArray<Int>(path, 1, path.size() - 1 : Nat);
          let subResult = editFrom(comment.subComments, subPath, newMsg, caller);
          switch (subResult) {
            case (#Ok(subComments)) {
              result := List.push<Comment>({ comment with subComments }, result);
            };
            case (#Err(msg)) {
              return #Err(msg);
            };
          };
        };
      } else {
        result := List.push<Comment>(comment, result);
      };
    };

    if (not found) {
      return #Err("Comment not found");
    };

    return #Ok(result);
  };

  public func react(box: CommentBox, path: [Int], reaction: ?Bool, caller: Principal): ReactResult {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    let result = reactFrom(box.comments, path, reaction, caller);

    switch (result) {
      case (#Ok(comments)) {
        return #Ok({ box with comments; });
      };
      case (#Err(msg)) {
        return #Err(msg);
      };
    };
  };

  func reactFrom(list: List.List<Comment>, path: [Int], reaction: ?Bool, caller: Principal): { #Ok : List.List<Comment>; #Err : Text } {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    var result = List.nil<Comment>();
    var found = false;

    for (comment in List.toIter(List.reverse(list))) {
      if (comment.created_at == path[0] and not found) {
        found := true;
        if (path.size() == 1) {
          var likes = comment.likes;
          var dislikes = comment.dislikes;
          
          switch (reaction) {
            case (?true) { // Like
              likes := addIfNotInclude<Principal>(likes, caller, Principal.equal);
              dislikes := removeFromArray<Principal>(dislikes, caller, Principal.equal);
            };
            case (?false) { // Dislike
              dislikes := addIfNotInclude<Principal>(dislikes, caller, Principal.equal);
              likes := removeFromArray<Principal>(likes, caller, Principal.equal);
            };
            case (null) { // Clear
              likes := removeFromArray<Principal>(likes, caller, Principal.equal);
              dislikes := removeFromArray<Principal>(dislikes, caller, Principal.equal);
            };
          };

          let reactedComment = {
            comment with
            likes = likes;
            dislikes = dislikes;
          };
          result := List.push<Comment>(reactedComment, result);
        } else {
          let subPath = Array.subArray<Int>(path, 1, path.size() - 1 : Nat);
          let subResult = reactFrom(comment.subComments, subPath, reaction, caller);
          switch (subResult) {
            case (#Ok(subComments)) {
              result := List.push<Comment>({ comment with subComments }, result);
            };
            case (#Err(msg)) {
              return #Err(msg);
            };
          };
        };
      } else {
        result := List.push<Comment>(comment, result);
      };
    };

    if (not found) {
      return #Err("Comment not found");
    };

    return #Ok(result);
  };
  
  public func delete(box: CommentBox, path: [Int], caller: Principal): DeleteResult {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    let result = deleteFrom(box.comments, path, caller);

    switch (result) {
      case (#Ok(comments)) {
        return #Ok({ box with comments;});
      };
      case (#Err(msg)) {
        return #Err(msg);
      };
    };
  };

  func deleteFrom(list: List.List<Comment>, path: [Int], caller: Principal): { #Ok : List.List<Comment>; #Err : Text } {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    var result = List.nil<Comment>();
    var found = false;

    for (comment in List.toIter(List.reverse(list))) {
      if (comment.created_at == path[0] and not found) {
        found := true;
        if (path.size() == 1) {
          if (caller == comment.creator) {
            let anonymizedComment = {
              comment with
              msg = "";
              likes = [];
              dislikes = [];
              last_modification = ?now();
            };
            result := List.push<Comment>(anonymizedComment, result);
          } else {
            return #Err("Access denied");
          };
        } else {
          let subPath = Array.subArray<Int>(path, 1, path.size() - 1 : Nat);
          let subResult = deleteFrom(comment.subComments, subPath, caller);
          switch (subResult) {
            case (#Ok(subComments)) {
              result := List.push<Comment>({ comment with subComments }, result);
            };
            case (#Err(msg)) {
              return #Err(msg);
            };
          };
        };
      } else {
        result := List.push<Comment>(comment, result);
      };
    };

    if (not found) {
      return #Err("Comment not found");
    };

    return #Ok(result);
  };


  public type Like = {
    #Like;
    #Dislike;
    #Clear;
  };

  // ===== Aux functions ===== //

  func pushBack<T>(input : T, list : List.List<T>) : List.List<T> {
    switch list {
      case null {
        return ?(input, null);
      };
      case (?(head, tail)) {
        return ?(head, pushBack(input, tail));
      };
    };
  };

  // ======= functions ======= //

  public func newComment(msg : Text, caller : Principal) : Comment {
    {
      created_at : Int = now();
      creator : Principal = caller;
      dislikes : [Principal] = [];
      last_modification : ?Int = null;
      likes : [Principal] = [];
      msg;
      subComments = List.nil<Comment>();
    };
  };

  public func newBox({ depthLimit : Nat }) : CommentBox {
    { depthLimit; comments = List.nil<Comment>(); size = 0; };
  };


  public func push(box : CommentBox, input : Comment, path : [Int]) : PushResult {

    if (path.size() >= box.depthLimit) { 
      return #Err( "Nesting limit exceeded" ); 
    };
    
    // Caso base de recursion 
    if (path.size() == 0) {
      // se inserta el comentario y se incrementa el campo size del box
      let comments = pushBack<Comment>(input, box.comments);
      let size = box.size + 1;

      return #Ok({ box with comments ; size});
    } else {
      // Caso recursivo 
      var commentsResult = List.nil<Comment>();
      var foundParent = false;
      var newBoxSize = box.size;

      for (comment in List.toIter(List.reverse(box.comments))) {
        if (comment.created_at == path[0] and not foundParent) {
          //Siguiente comentario objetivo del path
          foundParent := true;
          let subPath = Array.subArray<Int>(path, 1, path.size() - 1 : Nat);
          let subBox = { box with comments = comment.subComments }; 

          // Llamada recursiva
          switch (push(subBox, input, subPath)) { 
            case (#Ok (subBox)) {
              // Éxito: La recursión retornó una caja con el nuevo size y comentarios
              newBoxSize := subBox.size;
              commentsResult := List.push<Comment>({ comment with subComments = subBox.comments }, commentsResult);
            };
            case (#Err (msg)) {
              // commentsResult := List.push<Comment>(comment, commentsResult); 
              return #Err(msg); 
            };
          };
        } else {
          // No es el comentario objetivo
          commentsResult := List.push<Comment>(comment, commentsResult);
        };
      };

      if (not foundParent) {
        return #Err(
          "Invalid path"
        );
      };

      return #Ok({ box with comments = commentsResult; size = newBoxSize });
    };
  };

  public func pushLike(list : List.List<Comment>, like : Like, path : [Int]) : List.List<Comment> {
    // TODO
    null;
  };

  public func getComment(list : List.List<Comment>, path : [Int]) : ?Comment {
    if (path.size() == 0) { return null };

    for (comment in List.toIter(List.reverse(list))) {
      if (comment.created_at == path[0]) {
        if (path.size() == 1) {
          return ?comment;
        } else {
          return getComment(comment.subComments, Array.subArray<Int>(path, 1, path.size() -1 : Nat));
        };
      };
    };
    return null;
  };

  

};
