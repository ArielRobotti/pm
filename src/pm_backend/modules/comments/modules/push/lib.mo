import List "mo:base/List";
import Array "mo:base/Array";
import { now } "mo:base/Time";
import Types "../../types";
import FileStorage "../../../fileStorage";


module {

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
  
  public func push(box : Types.CommentBox, input : Types.Comment, path : [Int]) : Types.PushResult {

    if (path.size() >= box.depthLimit) { 
      return #Err( "Nesting limit exceeded" ); 
    };
    
    // Caso base de recursion 
    if (path.size() == 0) {
      // se inserta el comentario y se incrementa el campo size del box
      let comments = pushBack<Types.Comment>(input, box.comments);
      let size = box.size + 1;

      return #Ok({ box with comments ; size});
    } else {
      // Caso recursivo 
      var commentsResult = List.nil<Types.Comment>();
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
              commentsResult := List.push<Types.Comment>({ comment with subComments = subBox.comments }, commentsResult);
            };
            case (#Err (msg)) {
              // commentsResult := List.push<Types.Comment>(comment, commentsResult); 
              return #Err(msg); 
            };
            case (#RequireFileUpload(_)) { 
              // TODO revisar caso
            }
          };
        } else {
          // No es el comentario objetivo
          commentsResult := List.push<Types.Comment>(comment, commentsResult);
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

}