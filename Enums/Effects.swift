//
//  Effects.swift
//  ImagesInVideo
//
//  Created by Даниил Мухсинятов on 07.03.2023.
//

import UIKit
import CoreML
import CoreImage.CIFilterBuiltins

enum Effects {
    
    private func returnVisualEffect() -> ((UIImage, UIImage, CIImage?) -> [UIImage]?)? {
        switch self {
        case .not:
            return nil
        case .visualEffect1:
            return visualEffect1
        case .visualEffect2:
            return visualEffect2
        case .visualEffect3:
            return visualEffect3
        case .visualEffect4:
            return visualEffect4
        case .visualEffect5:
            return visualEffect5
        }
    }
    

    private func visualEffect1(_ pastImage: UIImage, currentImage: UIImage, mask: CIImage?) -> [UIImage]? {
        var result = [UIImage]()
        let imagesProcessing = ImagesProcessing()
        guard let mask = mask else { return nil }
        guard let resultImage = imagesProcessing.applyMaskWithAnySize(image: currentImage, mask: mask) else { return nil }
        result.append(imagesProcessing.mergeImage(resultImage, pastImage))
        result.append(currentImage)
        return result
    }

    private func visualEffect2(_ pastImage: UIImage, currentImage: UIImage, mask: CIImage?) -> [UIImage]? {
        let imagesProcessing = ImagesProcessing()
        var result = [UIImage]()
        guard let mask = mask else { return nil }
        guard let firstImageWithMask = imagesProcessing.applyMaskWithAnySize(image: currentImage, mask: mask) else { return nil }
        guard let secondImageWithMask = imagesProcessing.applyMaskWithAnySize(image: pastImage, mask: mask) else { return nil }

        result.append(imagesProcessing.mergeImage(firstImageWithMask, pastImage))

        let imageForMerge = imagesProcessing.mergeImage(secondImageWithMask, currentImage)
        result.append(imagesProcessing.mergeImageForVE2(firstImageWithMask, imageForMerge))

        result.append(currentImage)

        return result
    }

    private func visualEffect3(_ pastImage: UIImage, currentImage: UIImage, mask: CIImage?) -> [UIImage]? {
        var result = [UIImage]()
        let imagesProcessing = ImagesProcessing()
        guard let mask = mask else { return nil }
        guard let imageWithMask = imagesProcessing.applyMaskWithAnySize(image: currentImage, mask: mask) else { return nil }

        let imageVMWidth = imageWithMask.size.width
        let imageVMHeight = imageWithMask.size.height

        let targetSizeForImage = CGSize(width: imageVMWidth * 1.1, height: imageVMHeight * 1.1)
        guard let resizeImage = imageWithMask.resizeImage(targetSize: targetSizeForImage) else { return nil }

        guard let secondImageWithMask = imagesProcessing.applyMaskWithAnySize(image: pastImage, mask: mask) else { return nil }

        let imageForMerge = imagesProcessing.mergeImage(secondImageWithMask, currentImage)
        result.append(imagesProcessing.mergeImageForVE3(resizeImage, pastImage))
        result.append(imagesProcessing.mergeImageForVE3(resizeImage, imageForMerge))
        result.append(currentImage)

        return result
    }

    private func visualEffect4(_ pastImage: UIImage, currentImage: UIImage, mask: CIImage?) -> [UIImage]? {
        var result = [UIImage]()
        let imagesProcessing = ImagesProcessing()
        guard let mask = mask else { return nil }

        guard let pastImageWithMask = imagesProcessing.applyMaskWithAnySize(image: pastImage, mask: mask) else { return nil }

        let imageVMWidth = pastImageWithMask.size.width
        let imageVMHeight = pastImageWithMask.size.height

        let targetSizeForImage = CGSize(width: imageVMWidth * 1.6, height: imageVMHeight * 1.6)

        guard let bigMask = UIImage(ciImage: mask).resizeImage(targetSize: targetSizeForImage) else { return nil }
        let ciBM = CIImage(cgImage: bigMask.cgImage!)
        guard let pastImageWithBigMask = imagesProcessing.applyMaskWithAnySize(image: pastImage, mask: ciBM) else { return nil }

        result.append(imagesProcessing.mergeImageForVE3(pastImageWithBigMask, currentImage))
        result.append(imagesProcessing.mergeImageForVE3(pastImageWithMask, currentImage))
        result.append(currentImage)

      return result
    }

    private func visualEffect5(_ pastImage: UIImage, currentImage: UIImage, mask: CIImage?) -> [UIImage]? {
        var result = [UIImage]()
        let imagesProcessing = ImagesProcessing()
        guard let mask = mask else { return nil }
        guard let pastImageWithMasc = imagesProcessing.applyMaskWithAnySize(image: pastImage, mask: mask) else { return nil }

        let imageVMWidth = pastImageWithMasc.size.width
        let imageVMHeight = pastImageWithMasc.size.height

        let targetSizeForImage = CGSize(width: imageVMWidth * 1.2, height: imageVMHeight * 1.2)
        guard let resizeImage = pastImageWithMasc.resizeImage(targetSize: targetSizeForImage) else { return nil }

        let currentImageWithMask = imagesProcessing.applyMaskWithAnySize(image: currentImage, mask: mask)!
        let imageForMerge = imagesProcessing.mergeImageForVE3(pastImageWithMasc, currentImage).rotate(radians: -0.1)!
        result.append(imagesProcessing.mergeImageForVE3(resizeImage, currentImage).rotate(radians: -0.1)!)
        result.append(imageForMerge)
        result.append(imagesProcessing.mergeImageForVE3(currentImageWithMask, imageForMerge))
        result.append(currentImage)

      return result
    }

    func process(_ imageAndEffect: ImageAndEffect, index: Int, mask: CIImage?) -> [UIImage]? {
        switch self {

        case .not:
            guard let image = UIImage(named: imageAndEffect.nameImage) else { return nil }
            return [image]

        case .visualEffect1, .visualEffect2, .visualEffect3, .visualEffect4, .visualEffect5:
            guard index != 0 else { return nil }
            guard let image = UIImage(named: imageAndEffect.nameImage) else { return nil }
            let previousImageName = "\(index)"
            guard let first = UIImage(named: previousImageName) else { return nil }
            guard let visualEffect = returnVisualEffect()?(first, image, mask) else { return nil }
            return visualEffect
        }
    }
    
    case not
    case visualEffect1
    case visualEffect2
    case visualEffect3
    case visualEffect4
    case visualEffect5
}
