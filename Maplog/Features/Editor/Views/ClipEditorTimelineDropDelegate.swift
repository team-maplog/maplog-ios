//
//  ClipEditorTimelineDropDelegate.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
//

import SwiftUI

struct ClipEditorTimelineDropDelegate: DropDelegate {
    let targetID: UUID // 현재 드래그로 지나가는 카드 ID
    
    @Binding var draggingID: UUID? // 지금 사용자가 잡고 있는 카드 ID
    
    let onMove: (UUID, UUID) -> Void // 실제 순서 변경은 ViewModel에 맡기는 통로
    
    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != targetID else {
            return
        }
        
        onMove(draggingID, targetID)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
