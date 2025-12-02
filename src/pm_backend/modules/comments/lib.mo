import Push "./modules/push";
import Delete "./modules/delete";
import Edit "./modules/edit";
import React "./modules/react";
import Init "./modules/init";
import Get "./modules/get";
import Types "./types";
import WorkspaceTypes "../../types";
import Map "mo:map/Map";
import { ihash } "mo:map/Map";
import Principal "mo:base/Principal";
import { now } "mo:base/Time";
import Array "mo:base/Array";
import Notifications "../notifications"

module {
    // Types
    public type CommentBox = Types.CommentBox;
    public type PushResult = Types.PushResult;
    public type DeleteResult = Types.DeleteResult;
    public type EditResult = Types.EditResult;
    public type ReactResult = Types.ReactResult;
    public type Comment = Types.Comment;
    public type Like = Types.Like;

    // Pure Functions
    public let push = Push.push;
    public let delete = Delete.delete;
    public let edit = Edit.edit;
    public let react = React.react;
    public let newComment = Init.newComment;
    public let newBox = Init.newBox;
    public let getComment = Get.getComment;

    // Stateful functions
    
    func inArray<T>(a : [T], e : T, equal : (T, T) -> Bool) : Bool {
        for (elem in a.vals()) {
          if (equal(elem, e)) { return true };
        };
        false;
    };

    public func pushComment(s: WorkspaceTypes.State, input: {entity: WorkspaceTypes.Entity; path: [Int]; msg: Text}, caller: Principal): PushResult{ 
        switch (input.entity) {
          case (#Project(id)) {
            switch (Map.get<WorkspaceTypes.UID, WorkspaceTypes.Project>(s.projects, ihash, id)){
              case null { return #Err("Project not found") };
              case ( ?project ) {
                if (not inArray<Principal>(project.members, caller, Principal.equal) and caller != project.projectOwner){
                  return #Err("Access denied for the caller")
                };
                let pushCommentResponse = push(project.commentBox, newComment(input.msg, caller), input.path);
                let notification: Notifications.Notification = {
                  date = now();
                  kind = #NewComment({autor = caller; msg = input.msg});
                  read = false;
                  resume  = input.msg;
                };
                Notifications.batchNotification(
                  s.userNotifications, 
                  notification, 
                  Array.filter<Principal>(project.members, func member = member != caller)
                );
                
                switch pushCommentResponse {
                  case (#Ok(updateCommentBox)) {
                    ignore Map.put<WorkspaceTypes.UID, WorkspaceTypes.Project>(s.projects, ihash, id, {project with commentBox = updateCommentBox });
                    #Ok(updateCommentBox)
                  };
                  case (#Err(e)){ return #Err(e) };
                  case _ { #Err("Unexpected error")}
                }
              }
            }
          };
          case _ { #Err("not implemented yet")}
        }
    };

    public func deleteComment(s: WorkspaceTypes.State, e: WorkspaceTypes.Entity, path: [Int], caller: Principal): DeleteResult {
        switch e {
          case (#Project(id)) {
            switch (Map.get<WorkspaceTypes.UID, WorkspaceTypes.Project>(s.projects, ihash, id)) {
              case null { return #Err("Project not found") };
              case (?project) {
                if (not inArray<Principal>(project.members, caller, Principal.equal) and caller != project.projectOwner) {
                  return #Err("Access denied for the caller")
                };
                let deleteCommentResponse = delete(project.commentBox, path, caller);
                switch (deleteCommentResponse) {
                  case (#Ok(updateCommentBox)) {
                    ignore Map.put<WorkspaceTypes.UID, WorkspaceTypes.Project>(s.projects, ihash, id, { project with commentBox = updateCommentBox });
                    return #Ok(updateCommentBox)
                  };
                  case (#Err(e)) { return #Err(e) }
                };
              };
            };
          };
          case (#Area(path)) {
            assert(path.size() >= 2);
            switch(Map.get<WorkspaceTypes.UID, WorkspaceTypes.Project>(s.projects, ihash, path[0])) {
              case null { return #Err("Project not found")};
              case ( ?project ) {
                return #Err("project Ok. Function not implemented yet")
              }
            };
          };
          case _ { #Err("not implemented yet") }
        }
    };

    public func editComment(s: WorkspaceTypes.State, e: WorkspaceTypes.Entity, path: [Int], newMsg: Text, caller: Principal): EditResult {
        switch e {
          case (#Project(id)) {
            switch (Map.get<WorkspaceTypes.UID, WorkspaceTypes.Project>(s.projects, ihash, id)) {
              case null { return #Err("Project not found") };
              case (?project) {
                if (not inArray<Principal>(project.members, caller, Principal.equal) and caller != project.projectOwner) {
                  return #Err("Access denied for the caller")
                };
                let editCommentResponse = edit(project.commentBox, path, newMsg, caller);
                switch (editCommentResponse) {
                  case (#Ok(updateCommentBox)) {
                    ignore Map.put<WorkspaceTypes.UID, WorkspaceTypes.Project>(s.projects, ihash, id, { project with commentBox = updateCommentBox });
                    #Ok(updateCommentBox)
                  };
                  case (#Err(e)) { return #Err(e) }
                };
              };
            };
          };
          case _ { #Err("not implemented yet") }
        }
    };

    public func reactToComment(s: WorkspaceTypes.State, e: WorkspaceTypes.Entity, path: [Int], reaction: ?Bool, caller: Principal): ReactResult {
        switch e {
            case (#Project(id)) {
                switch (Map.get<WorkspaceTypes.UID, WorkspaceTypes.Project>(s.projects, ihash, id)) {
                    case null { return #Err("Project not found") };
                    case (?project) {
                        if (not inArray<Principal>(project.members, caller, Principal.equal) and caller != project.projectOwner) {
                            return #Err("Access denied for the caller")
                        };
                        let reactCommentResponse = react(project.commentBox, path, reaction, caller);
                        switch (reactCommentResponse) {
                            case (#Ok(updateCommentBox)) {
                                ignore Map.put<WorkspaceTypes.UID, WorkspaceTypes.Project>(s.projects, ihash, id, { project with commentBox = updateCommentBox });
                                #Ok(updateCommentBox)
                            };
                            case (#Err(e)) { return #Err(e) }
                        };
                    };
                };
            };
            case _ { #Err("not implemented yet") }
        }
    };
}