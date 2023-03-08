//
//  ImageProcessing.swift
//  ImagesInVideo
//
//  Created by Даниил Мухсинятов on 02.03.2023.
//

import Foundation
import UIKit
import CoreML
import CoreImage.CIFilterBuiltins

class ImagesProcessing {
    
    private func mergeImage(_ image: UIImage, _ secondImage: UIImage?) -> UIImage {
        let topImage = image
        let theSizeOfTheLargerSide = topImage.size.height < topImage.size.width ? topImage.size.width : topImage.size.height
        
        let bottomImage = secondImage == nil ? UIImage.createBlackImage(theSizeOfTheLargerSide, theSizeOfTheLargerSide) : secondImage!
        var size = CGSize()
        if secondImage == nil {
            size = CGSize(width: theSizeOfTheLargerSide, height: theSizeOfTheLargerSide)
        } else {
            size = CGSize(width: topImage.size.width, height: topImage.size.height)
        }
        UIGraphicsBeginImageContext(size)
        let areaSize = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        bottomImage.draw(in: areaSize)
        let areaSizeTopImage = CGRect(x: 0, y: 0, width: topImage.size.width, height: topImage.size.height)
        topImage.draw(in: areaSizeTopImage, blendMode: .normal, alpha: 1)
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    private func mergeImageForVE2(_ image: UIImage, _ secondImage: UIImage) -> UIImage {
        let topImage = image
        let bottomImage = secondImage
        
        var size = CGSize()
        size = CGSize(width: bottomImage.size.width, height: bottomImage.size.height)
        
        UIGraphicsBeginImageContext(size)
        let areaSize = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        bottomImage.draw(in: areaSize)
        let areaSizeTopImage = CGRect(x: size.width / 10, y: -size.height / 15, width: topImage.size.width, height: topImage.size.height)
        topImage.draw(in: areaSizeTopImage, blendMode: .normal, alpha: 1)
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    private func mergeImageForVE3(_ image: UIImage, _ secondImage: UIImage) -> UIImage {
        let topImage = image
        let bottomImage = secondImage
        
        let bottomImageWidth = bottomImage.size.width
        let bottomImageHeight = bottomImage.size.height
        let topImageWidth = topImage.size.width
        let topImageHeight = topImage.size.height
        
        let offsetY = topImageHeight - bottomImageHeight
        let offsetX = topImageWidth - bottomImageWidth
        
        var size = CGSize()
        size = CGSize(width: bottomImageWidth, height: bottomImageHeight)
        
        UIGraphicsBeginImageContext(size)
        let areaSize = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        bottomImage.draw(in: areaSize)
        let areaSizeTopImage = CGRect(x: -offsetX / 2, y: -offsetY / 2, width: topImageWidth, height: topImageHeight)
        topImage.draw(in: areaSizeTopImage, blendMode: .normal, alpha: 1)
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    private func cropImage(_ inputImage: UIImage, rawImage: UIImage) -> CIImage? {
        let sourceImage = inputImage
        let rawHeight = rawImage.size.height
        let rawWidth = rawImage.size.height
        
        let heightReduction = rawHeight > rawWidth ? rawHeight - rawWidth : 0
        let widthReduction = rawWidth > rawHeight ? rawWidth - rawHeight : 0
        
        let sideLength = min(
            sourceImage.size.width,
            sourceImage.size.height
        )

        let sourceSize = sourceImage.size
        let xOffset = (sourceSize.width - sideLength) - heightReduction
        let yOffset = (sourceSize.height - sideLength) - widthReduction

        let cropRect = CGRect(
            x: xOffset,
            y: yOffset,
            width: sideLength,
            height: sideLength
        ).integral

        let sourceCGImage = sourceImage.cgImage!
        let croppedCGImage = sourceCGImage.cropping(
            to: cropRect
        )!
        return CIImage(cgImage: croppedCGImage)
    }
    
    private func createMask(_ image: UIImage) -> CIImage? {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        let model = try! segmentation_8bit()
        let uikitImage = image
        let staticImage = CIImage(image: uikitImage)
        
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
             kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let width:Int = Int(uikitImage.size.width)
        
        let height:Int = Int(uikitImage.size.height)
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_32BGRA,
                            attrs,
                            &pixelBuffer)
        let context = CIContext()
        context.render(staticImage!, to: pixelBuffer!)
        
        guard let prediction = try? model.prediction(img: pixelBuffer!) else { return nil }
        let maskImage = CIImage(cvPixelBuffer: prediction.var_2274)
        return maskImage
    }
    
    private func applyMask(maskImage: CIImage, pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = maskImage
        
        let context = CIContext(options: nil)
        
        guard let inputCGImage = context.createCGImage(CIImage(cvPixelBuffer: pixelBuffer), from: CIImage(cvPixelBuffer: pixelBuffer).extent) else {
            return nil
        }
        
        let blendFilter = CIFilter.blendWithRedMask()
        
        blendFilter.inputImage = CIImage(cgImage: inputCGImage)
        blendFilter.maskImage = ciImage
        
        guard let outputCIImage = blendFilter.outputImage?.oriented(.up),
              let outputCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: outputCGImage)
    }
    
    func createMaskWithAnySize(image: UIImage)-> CIImage? {
        let mergedImage = mergeImage(image, nil)
        let resizeImage = mergedImage.resizeImage(targetSize: CGSize(width: 1024, height: 1024))
        let mask = createMask(resizeImage!)
        guard let mask = mask else { return nil }
        guard let resizeMask = UIImage(ciImage: mask).resizeImage(targetSize: CGSize(width: mergedImage.size.width, height: mergedImage.size.height)) else { return nil }
        
        let cropMask = cropImage(resizeMask, rawImage: image)
        return cropMask
    }
    
    func applyMaskWithAnySize(image: UIImage, mask: CIImage)-> UIImage? {
        guard let pixelB = image.createPixelBuffer() else { return nil }
        guard let resultImage = applyMask(maskImage: mask, pixelBuffer: pixelB) else { return nil }
        return resultImage
    }
    
    private func visualEffect1(_ pastImage: UIImage, currentImage: UIImage) -> [UIImage]? {
        var result = [UIImage]()
        let image = currentImage
        guard let mask = createMaskWithAnySize(image: image) else { return nil }
        guard let resultImage = applyMaskWithAnySize(image: image, mask: mask) else { return nil }
        result.append(mergeImage(resultImage, pastImage))
        result.append(image)
        return result
    }
    
    private func visualEffect2(_ pastImage: UIImage, currentImage: UIImage) -> [UIImage]? {
        var result = [UIImage]()
        guard let mask = createMaskWithAnySize(image: currentImage) else { return nil }
        guard let firstImageWithMask = applyMaskWithAnySize(image: currentImage, mask: mask) else { return nil }
        guard let secondImageWithMask = applyMaskWithAnySize(image: pastImage, mask: mask) else { return nil }
        
        result.append(mergeImage(firstImageWithMask, pastImage))
        
        let imageForMerge = mergeImage(secondImageWithMask, currentImage)
        result.append(mergeImageForVE2(firstImageWithMask, imageForMerge))
        
        result.append(currentImage)
        
        return result
    }
    
    private func visualEffect3(_ pastImage: UIImage, currentImage: UIImage) -> [UIImage]? {
        var result = [UIImage]()
        
        guard let mask = createMaskWithAnySize(image: currentImage) else { return nil }
        guard let imageWithMask = applyMaskWithAnySize(image: currentImage, mask: mask) else { return nil }
        
        let imageVMWidth = imageWithMask.size.width
        let imageVMHeight = imageWithMask.size.height
        
        let targetSizeForImage = CGSize(width: imageVMWidth * 1.1, height: imageVMHeight * 1.1)
        guard let resizeImage = imageWithMask.resizeImage(targetSize: targetSizeForImage) else { return nil }
        
        guard let secondImageWithMask = applyMaskWithAnySize(image: pastImage, mask: mask) else { return nil }
        
        let imageForMerge = mergeImage(secondImageWithMask, currentImage)
        result.append(mergeImageForVE3(resizeImage, pastImage))
        result.append(mergeImageForVE3(resizeImage, imageForMerge))
        result.append(currentImage)

        return result
    }
    
    private func visualEffect4(_ pastImage: UIImage, currentImage: UIImage) -> [UIImage]? {
        var result = [UIImage]()
        
        guard let mask = createMaskWithAnySize(image: currentImage) else { return nil }
       
        guard let pastImageWithMask = applyMaskWithAnySize(image: pastImage, mask: mask) else { return nil }
        
        let imageVMWidth = pastImageWithMask.size.width
        let imageVMHeight = pastImageWithMask.size.height
        
        let targetSizeForImage = CGSize(width: imageVMWidth * 1.6, height: imageVMHeight * 1.6)
        
        guard let bigMask = UIImage(ciImage: mask).resizeImage(targetSize: targetSizeForImage) else { return nil }
        let ciBM = CIImage(cgImage: bigMask.cgImage!)
        guard let pastImageWithBigMask = applyMaskWithAnySize(image: pastImage, mask: ciBM) else { return nil }
        
        result.append(mergeImageForVE3(pastImageWithBigMask, currentImage))
        result.append(mergeImageForVE3(pastImageWithMask, currentImage))
        result.append(currentImage)
        
      return result
    }
    
    private func visualEffect5(_ pastImage: UIImage, currentImage: UIImage) -> [UIImage]? {
        var result = [UIImage]()
        
        guard let mask = createMaskWithAnySize(image: currentImage) else { return nil }
        guard let pastImageWithMasc = applyMaskWithAnySize(image: pastImage, mask: mask) else { return nil }
        
        let imageVMWidth = pastImageWithMasc.size.width
        let imageVMHeight = pastImageWithMasc.size.height
        
        let targetSizeForImage = CGSize(width: imageVMWidth * 1.2, height: imageVMHeight * 1.2)
        guard let resizeImage = pastImageWithMasc.resizeImage(targetSize: targetSizeForImage) else { return nil }
        
        let currentImageWithMask = applyMaskWithAnySize(image: currentImage, mask: mask)!
        let imageForMerge = mergeImageForVE3(pastImageWithMasc, currentImage).rotate(radians: -0.1)!
        result.append(mergeImageForVE3(resizeImage, currentImage).rotate(radians: -0.1)!)
        result.append(imageForMerge)
        result.append(mergeImageForVE3(currentImageWithMask, imageForMerge))
        result.append(currentImage)
        
      return result
    }
    
    
    func createAnArrayOfImages(array: [ImageAndEffect]) async -> [UIImage]? {
        var result = [UIImage]()
        
        for (index, imageAndEffect) in array.enumerated() {
            switch  imageAndEffect.effect {
                
            case .not:
                guard let image = UIImage(named: imageAndEffect.nameImage) else { return nil }
                result.append(image)
                
            case .visualEffect1:
                guard index != 0 else { return nil }
                guard let image = UIImage(named: imageAndEffect.nameImage) else { return nil }
                let previousImageName = "\(index)"
                guard let first = UIImage(named: previousImageName) else { return nil }
                guard let visualEffect = visualEffect1(first, currentImage: image) else { return nil }
                result += visualEffect
                
            case .visualEffect2:
                guard index != 0 else { return nil }
                guard let image = UIImage(named: imageAndEffect.nameImage) else { return nil }
                let previousImageName = "\(index)"
                guard let first = UIImage(named: previousImageName) else { return nil }
                guard let visualEffect = visualEffect2(first, currentImage: image) else { return nil }
                result += visualEffect
                
            case .visualEffect3:
                guard index != 0 else { return nil }
                guard let image = UIImage(named: imageAndEffect.nameImage) else { return nil }
                let previousImageName = "\(index)"
                guard let first = UIImage(named: previousImageName) else { return nil }
                guard let visualEffect = visualEffect3(first, currentImage: image) else { return nil }
                result += visualEffect
                
            case .visualEffect4:
                guard index != 0 else { return nil }
                guard let image = UIImage(named: imageAndEffect.nameImage) else { return nil }
                let previousImageName = "\(index)"
                guard let first = UIImage(named: previousImageName) else { return nil }
                guard let visualEffect = visualEffect4(first, currentImage: image) else { return nil }
                result += visualEffect
                
            case .visualEffect5:
                guard index != 0 else { return nil }
                guard let image = UIImage(named: imageAndEffect.nameImage) else { return nil }
                let previousImageName = "\(index)"
                guard let first = UIImage(named: previousImageName) else { return nil }
                guard let visualEffect = visualEffect5(first, currentImage: image) else { return nil }
                result += visualEffect
            }
        }
        return result.reversed()
    }
}
