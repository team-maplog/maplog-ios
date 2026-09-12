//
//  MediaRepositoryError.swift
//  Maplog
//
//  Created by 한채림 on 7/30/26.
//

import Foundation

enum MediaDraftRepositoryError: Error {
    case sourceFileNotFound
    case draftNotFound
    case invalidStoredRecord
}
