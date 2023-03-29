//
//  ImageProcessing.swift
//  ImagesInVideo
//
//  Created by Даниил Мухсинятов on 02.03.2023.
//

import Foundation
import UIKit
import CoreML

class ImagesProcessing {
    
    func mergeImage(_ image: UIImage, _ secondImage: UIImage?) -> UIImage {
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
    
    func mergeImageForVE2(_ image: UIImage, _ secondImage: UIImage) -> UIImage {
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
    
    func mergeImageForVE3(_ image: UIImage, _ secondImage: UIImage) -> UIImage {
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
    
    func cropImage(_ inputImage: UIImage, rawImage: UIImage) -> CIImage? {
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
    
    func createMask(_ image: UIImage) -> CIImage? {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        let model = try! segmentation_8bit()
        let pixelBuffer = image.createPixelBuffer()
        guard let prediction = try? model.prediction(img: pixelBuffer!) else { return nil }
        let maskImage = CIImage(cvPixelBuffer: prediction.var_2274)
        return maskImage
    }
    
    func applyMask(maskImage: CIImage, pixelBuffer: CVPixelBuffer) -> UIImage? {
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
    
    func createMasksWithAnySize(_ images: [UIImage], indexs: [Int]) async -> [Int:CIImage] {
        var result = [Int: CIImage]()
        var mergeImages = [UIImage]()
        var resizeImages = [UIImage]()
        var resizeMaskImages = [UIImage]()
        var masks = [CIImage]()
        var resizeMasks = [CIImage]()
        
        await withTaskGroup(of: UIImage.self, body: { group in
            for image in images {
                group.addTask { [self] in
                    return mergeImage(image, nil)
                }
            }
            for await image in group {
                mergeImages.append(image)
            }
        })

        await withTaskGroup(of: UIImage.self, body: { group in
            for image in mergeImages {
                group.addTask {
                    return image.resizeImage(targetSize: CGSize(width: 1024, height: 1024))!
                }
            }
            for await image in group {
                resizeImages.append(image)
            }
        })
        
        await withTaskGroup(of: CIImage.self, body: { group in
            for image in resizeImages {
                group.addTask(operation: { [self] in
                    createMask(image)!
                })
            }
            for await image in group {
                masks.append(image)
            }
        })
      
        await withTaskGroup(of: UIImage.self, body: { group in
            for index in 0..<masks.count {
                let image = masks[index]
                let size = mergeImages[index].size
                group.addTask(operation: {
                    UIImage(ciImage: image).resizeImage(targetSize: size)!
                })
            }
            for await image in group {
                resizeMaskImages.append(image)
            }
        })
       
        await withTaskGroup(of: CIImage.self, body: { group in
            for index in 0..<masks.count {
                let image = resizeMaskImages[index]
                let rawImage = images[index]
                group.addTask(operation: { [self] in
                    return cropImage(image, rawImage: rawImage)!
                })
            }
            for await image in group {
                resizeMasks.append(image)
            }
        })
      
        for index in 0..<indexs.count {
            result[indexs[index]] = resizeMasks[index]
        }
       
        return result
    }
    
    
    func applyMaskWithAnySize(image: UIImage, mask: CIImage)-> UIImage? {
        guard let pixelB = image.createPixelBuffer() else { return nil }
        guard let resultImage = applyMask(maskImage: mask, pixelBuffer: pixelB) else { return nil }
        return resultImage
    }
    
    func createAnArrayOfImages(array: [ImageAndEffect]) async -> [UIImage]? {
        var result = [UIImage]()
        
        await withTaskGroup(of: (Int, [UIImage]?).self) { group in
            var images = [UIImage]()
            var indexs = [Int]()
            for (index, imageAndEffect) in array.enumerated() {
                if imageAndEffect.effect != .not {
                    images.append(UIImage(imageLiteralResourceName: imageAndEffect.nameImage))
                    indexs.append(index)
                }
            }
            let masks = await createMasksWithAnySize(images, indexs: indexs)
            
            for (index, imageAndEffect) in array.enumerated() {
                group.addTask {
                    if imageAndEffect.effect != .not {
                        return (index, imageAndEffect.effect.process(imageAndEffect,
                                                                     index: index,
                                                                     mask: masks[index]!))
                    } else {
                        return (index, imageAndEffect.effect.process(imageAndEffect,
                                                                     index: index,
                                                                     mask: nil))
                    }
                }
            }
            for await (_, images) in group {
                result += images!
            }
        }
        
        return result.reversed()
    }
}
