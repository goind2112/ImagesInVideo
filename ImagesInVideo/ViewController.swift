//
//  ViewController.swift
//  ImagesInVideo
//
//  Created by Даниил Мухсинятов on 02.03.2023.
//

import UIKit
import AVKit

class ViewController: UIViewController {
    lazy var videoButton: UIButton = {
        let button = UIButton()
        button.setTitle("Present video", for: .normal)
        button.addTarget(nil, action: #selector(presentedVP), for: .touchUpInside)
        button.titleLabel?.font = .systemFont(ofSize: 20)
        button.backgroundColor = .orange
        button.setTitleColor(.black, for: .normal)
        button.layer.cornerRadius = 20
        return button
    }()
    
    lazy var label: UILabel = {
        let label = UILabel()
        label.text = "loading"
        label.font = .systemFont(ofSize: 40)
        label.isHidden = true
        return label
    }()
    
    func wave(_ word: String, index: Int) {
        var index = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let velue = word.enumerated().map{$0 == index ? "\($1.uppercased())" : "\($1)"}.joined()
            if velue != velue.lowercased() {
                self.label.text = velue
            }
            if index == word.count + 1 {
                index = 0
                self.label.text = word
            } else {
                index += 1
            }
            if self.videoButton.isHidden {
                self.wave(word, index: index)
            }
        }
    }
    
    func showVC(){
        let playerViewController = AVPlayerViewController()
        let player = AVPlayer(url: videoURL!)
        playerViewController.player = player
        present(playerViewController, animated: true) {
            player.play()
        }
    }
    
    var videoURL: URL? {
        didSet {
            showVC()
        }
    }
    
    @objc func presentedVP() {
        label.isHidden = false
        wave("loading", index: 0)
        videoButton.isHidden = true
        let musicURL = URL(filePath: Bundle.main.path(forResource: "music", ofType: "aac")!)
        
        Task.init(priority: .high, operation: {
            let images = await ImagesProcessing().createAnArrayOfImages(array: [
                ImageAndEffect(nameImage: "1", effect: .not),
                ImageAndEffect(nameImage: "2", effect: .visualEffect2),
                ImageAndEffect(nameImage: "3", effect: .visualEffect1),
                ImageAndEffect(nameImage: "4", effect: .visualEffect1),
                ImageAndEffect(nameImage: "5", effect: .visualEffect5),
                ImageAndEffect(nameImage: "6", effect: .visualEffect1),
                ImageAndEffect(nameImage: "7", effect: .visualEffect3),
                ImageAndEffect(nameImage: "8", effect: .visualEffect4)
            ])
            videoURL =  await VideoEditor().createClip(images: images!, music: musicURL)
            videoButton.isHidden = false
            label.isHidden = true
        })
    }
    
    func setupView() {
        view.addSubview(videoButton)
        view.addSubview(label)
    }
    
    func layout() {
        videoButton.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            videoButton.widthAnchor.constraint(equalToConstant: 300),
            videoButton.heightAnchor.constraint(equalToConstant: 60),
            
            label.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            
            videoButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            videoButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }
       
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupView()
        layout()
    }


}




