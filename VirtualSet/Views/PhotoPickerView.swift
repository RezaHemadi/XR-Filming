//
//  PhotoPickerView.swift
//  VirtualSet
//
//  Created by Reza on 10/6/21.
//

import Foundation
import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @EnvironmentObject var session: VSSession
    
    func makeUIViewController(context: Context) -> some UIViewController {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let photoPickerVC = PHPickerViewController(configuration: configuration)
        photoPickerVC.delegate = context.coordinator
        
        return photoPickerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
    
    func makeCoordinator() -> PhotoPicker.Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoPicker
        
        init(_ picker: PhotoPicker) {
            self.parent = picker
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            for image in results {
                if image.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    image.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] newImage, error in
                        if let error = error {
                            print("Can't load image \(error.localizedDescription)")
                        } else if let image = newImage as? UIImage {
                            self?.parent.session.didPickImage(image)
                        }
                      }
                    } else {
                      print("Can't load asset")
                    }
                  }
            parent.isPresented = false
        }
    }
}
