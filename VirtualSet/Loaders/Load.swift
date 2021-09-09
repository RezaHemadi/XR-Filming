//
//  DataLoader.swift
//  VirtualSet
//
//  Created by Reza on 9/6/21.
//

import Foundation

func load<T: Decodable>(fileName: String) -> T {
    let data: Data
    
    guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
        fatalError("could not find url for resourse name: \(fileName)")
    }
    
    do {
        try data = Data(contentsOf: url)
    } catch let error {
        fatalError("could not read data: %\(error.localizedDescription)")
    }
    
    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    } catch let error {
        fatalError("could not read data: \(error.localizedDescription)")
    }
}
