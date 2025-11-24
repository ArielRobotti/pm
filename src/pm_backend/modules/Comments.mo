import List "mo:base/List";
import Array "mo:base/Array";
import { now } "mo:base/Time";

module {

  // ======== Types ========= //

  public type CommentBox = {
    depthLimit : Nat;
    comments : List.List<Comment>;
    size: Nat
  };

  public type PushResult = { #Ok : CommentBox; #Err : Text };

  public type Comment = {
    created_at : Int;
    last_modification : ?Int;
    creator : Principal;
    msg : Text;
    likes : [Principal];
    dislikes : [Principal];
    subComments : List.List<Comment>;
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
  /*
  public func push(box : CommentBox, input : Comment, path : [Int]) : CommentBox {

    if (path.size() == 0) { // Condicion de salida de recursividad
      let size = box.size +1;
      let comments = pushBack<Comment>(input, box.comments);
      return { box with comments; size }
    } else {
      var boxUpdate = box;
      var commentsResult = List.nil<Comment>();

      for (comment in List.toIter(List.reverse(box.comments))) {
        if (comment.created_at == path[0]) {
          let subPath = Array.subArray<Int>(path, 1, path.size() - 1 : Nat);
          boxUpdate := push({ box with comments = comment.subComments }, input, subPath);
          let subComments = boxUpdate.comments; // Llamada recursiva
          commentsResult := List.push<Comment>({ comment with subComments }, commentsResult);
        } else {
          commentsResult := List.push<Comment>(comment, commentsResult);
        };
      };
      return { boxUpdate with comments = commentsResult };
    };
  };

  public func pushWraped(box : CommentBox, input : Comment, path : [Int]) : PushResult {
    if (path.size() >= box.depthLimit) {
      return #Err("Error Limit Recursion");
    };
    if (path.size() == 0) {
      return #Ok({ box with comments = pushBack<Comment>(input, box.comments) })// Condicion de salida de recursividad
    } else {
      // var commentsResult = List.nil<Comment>();

      // for (comment in List.toIter(List.reverse(box.comments))) {
      //   if (comment.created_at == path[0]) {
      //     let subPath = Array.subArray<Int>(path, 1, path.size() - 1 : Nat);
      //     let subComments = push({ box with comments = comment.subComments }, input, subPath).comments;
      //     commentsResult := List.push<Comment>({ comment with subComments }, commentsResult);
      //   } else {
      //     commentsResult := List.push<Comment>(comment, commentsResult);
      //   };
      // };
      let commentsResult = push(box, input, path);
      if (commentsResult.size == box.size){
        return #Err("Message not inserted");
      };
      return #Ok(commentsResult);
    };
  };

  */

  public func pushWraped(box : CommentBox, input : Comment, path : [Int]) : PushResult {

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
          switch (pushWraped(subBox, input, subPath)) { 
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
