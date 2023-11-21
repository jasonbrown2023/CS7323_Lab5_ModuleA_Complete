//
//  GenderModel.swift
//  CS5323_MLaaS
//
//  Created by jason brown on 25/08/1402 AP.
// change this for your server name!!!
let SERVER_URL = "http://10.2.1.249:8000"

import Foundation
import UIKit
import AVFoundation
import SwiftUI
import Foundation
import Accelerate

class SpeechModel : NSObject, AVAudioPlayerDelegate, AVAudioRecorderDelegate, URLSessionDelegate {
    
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    var mostFrequent:String
    var predictionReady:Bool
    var resps:[String]
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        return URLSession(configuration: sessionConfig,
                          delegate: self,
                          delegateQueue:self.operationQueue)
    }()
    
    let operationQueue = OperationQueue()
    var dsid:Int = 0
    var ringBuffer = RingBuffer()
    var soundRecorder = AVAudioRecorder()
    var soundPlayer = AVAudioPlayer()
    var fileName = "audioFile.m4a"
    //var fileName2 = "audioFile.m4a"
    var vc = ModuleAViewController()
    var cflag: Bool
    var timeData:[Float]
    var fftData:[Float]
    
    
    lazy var samplingRate:Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    //===================================================
    //Mark - Init
    override init(){
        BUFFER_SIZE = 8192 // unused
        self.cflag = false       //Conditional to know if recording
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        self.resps = [""] //variable to collect prediction responses
        self.mostFrequent = ""  //Most frequent from prediction
        self.predictionReady = false //Bool to see if prediction is ready
        super.init()
        setupRecorder() //Initialize recorder
        
    }
    
    //Setup recorder
    func setupRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Set up the audio session for play and record
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [])
            try audioSession.setActive(true)
            
            // Set up file path for recording
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let soundFilePath = documentPath.appendingPathComponent(fileName)
            
            // Define recording settings
            let recordSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatAppleLossless,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 320000,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 2,
            ]
            
            // Create and configure AVAudioRecorder
            soundRecorder = try AVAudioRecorder(url: soundFilePath, settings: recordSettings)
            soundRecorder.delegate = self
            soundRecorder.prepareToRecord()
        } catch {
            print("Error setting up audio session or recorder: \(error.localizedDescription)")
        }
    }
    
    //Record sound
    func recordSound() {
        
        if !soundRecorder.isRecording {
            do {
                // Activate audio session and start recording
                try AVAudioSession.sharedInstance().setActive(true)
                soundRecorder.record()
            } catch {
                print("Error starting recording: \(error.localizedDescription)")
            }
            
            
            cflag = true
            //Manually set is recording flag
        } else {
            // Stop recording if already recording
            soundRecorder.stop()
            
            cflag = false
            
        }
    }
    
    func playSound() {
        do {
            // Create and configure AVAudioPlayer for playback
            soundPlayer = try AVAudioPlayer(contentsOf: soundRecorder.url)
            soundPlayer.delegate = self
            soundPlayer.prepareToPlay()
            soundPlayer.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
    
    //To capture the fft data of test data to send labeled data to the server
    func play(withFps:Double, label:String){
        var timer2 = Timer()
        var runCount:Int = 0
        if let manager = self.audioManager{
                playSound()
                manager.play()
                //reader.play()
                manager.inputBlock = self.handleSoundData
                // repeat this fps times per second using the timer class
                //   every time this is called, we update the arrays "timeData" and "fftData"
                timer2 = Timer.scheduledTimer(withTimeInterval: 1.0/20, repeats: true) { _ in
                    runCount += 1
                    self.runEveryInterval(label:label)
                    if(runCount==10){
                        timer2.invalidate()
                    }
                }
            
        }
    }
    
    //To capture the fft data of test data to send unlabeled data to the server
    func play2(withFps:Double){
        var timer2 = Timer()
        var runCount:Int = 0
        if let manager = self.audioManager{
            soundPlayer.play()
            manager.play()
            //reader.play()
            manager.inputBlock = self.handleSoundData
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            timer2 = Timer.scheduledTimer(withTimeInterval: 1.0/20, repeats: true) { _ in
                runCount += 1
                self.runEveryInterval2()
                if(runCount==10){
                    timer2.invalidate()
                }
            }
        }
    }
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    // Sends: Training data with labels to be posted
    private func runEveryInterval(label:String){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData, // copied into this array
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData) // fft result is copied into fftData array
            postSound2(fftData: self.fftData, label: label)
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
        }
    }
    
    //Sends uplabeled data to test
    private func runEveryInterval2(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData, // copied into this array
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData) // fft result is copied into fftData array
            getPrediction(fftData:fftData)
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
        }
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    
    private func handleSpeakerQueryWithAudioFile(data:Optional<UnsafeMutablePointer<Float>>,
                                                 numFrames:UInt32,
                                                 numChannels: UInt32){
        if let file = self.fileReader{
            
            // read from file, loading into data (a float pointer)
            if let arrayData = data{
                // get samples from audio file, pass array by reference
                file.retrieveFreshAudio(arrayData,
                                        numFrames: numFrames,
                                        numChannels: numChannels)
                
            }
        }
    }
    
    
    //save the data into the buffer
    private func handleSound(data:Optional<UnsafeMutablePointer<Float>>,
                             numFrames:UInt32,
                             numChannels: UInt32){
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    //Read file
    private lazy var fileReader:AudioFileReader? = {
        // find song in the main Bundle
        if let url = Bundle.main.url(forResource: "audiofile", withExtension: "m4a"){
            // if we could find the url for the song in main bundle, setup file reader
            // the file reader is doing a lot here becasue its a decoder
            // so when it decodes the compressed mp3, it needs to know how many samples
            // the speaker is expecting and how many output channels the speaker has (mono, left/right, surround, etc.)
            var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url,
                                                   samplingRate: Float(audioManager!.samplingRate),
                                                   numChannels: audioManager!.numOutputChannels)
            
            tmpFileReader!.currentTime = 0.0 // start from time zero!
            print("Audio file succesfully loaded for \(url)")
            return tmpFileReader
        }else{
            print("Could not initialize audio input file")
            return nil
        }
    }()

    
//    func postSound() {
//        // Get the file path to upload
//        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let soundFilePath = documentPath.appendingPathComponent(fileName)
//        
//        let apiUrl = URL(string: "https://example.com/upload")
//        let session = URLSession.shared
//
//        // Prepare the URLRequest
//        var request = URLRequest(url: apiUrl!)
//        request.httpMethod = "POST"
//
//        // Create the upload task
//        let task = session.uploadTask(with: request, fromFile: soundFilePath) { (data, response, error) in
//            if let error = error {
//                print("Error uploading file: \(error)")
//            } else {
//                if let httpResponse = response as? HTTPURLResponse {
//                    print("Status code: \(httpResponse.statusCode)")
//
//                    if let responseData = data {
//                        // Process the response data if needed
//                        do {
//                            let json = try JSONSerialization.jsonObject(with: responseData, options: [])
//                            print("Response JSON: \(json)")
//                        } catch {
//                            print("Error parsing JSON response: \(error)")
//                        }
//                    }
//                }
//            }
//        }
//        
//        task.resume() //start task
//    }
    //==================================================
    //Posts FFT data to the tornado
    func postSound2( fftData:[Float], label: String) {
        // Get the file path to uploa
    
        let baseURL = "\(SERVER_URL)/AddDataPoint"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":self.fftData,
                                       "label":"\(label)",
                                       "dsid":self.dsid]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                if(error != nil){
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    print(jsonDictionary["feature"]!)
                    print(jsonDictionary["label"]!)
                }

        })
        
        postTask.resume() // start the task
    }
    //===========================================================
    //The below functions differ on sending training data and sending test data to test app
    // public function for starting processing of audio file data
    func startProcesingAudioFileForPlayback(withFps:Double, label:String){
        // set the output block to read from and play the audio file
        if let manager = self.audioManager,
           let fileReader = self.fileReader{
            manager.outputBlock = self.handleSpeakerQueryWithAudioFile
            fileReader.play() // tell file Reader to start filling its buffer
            manager.inputBlock = self.handleSoundData
            manager.play()
            //manager.outputBlock = self.printMax
            
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                self.runEveryInterval(label:label)
                
            }
            
        }
        
    }
    
    
    //Function to handle for test ffts
    func startProcesingAudioFileForPlayback2(withFps:Double){
        // set the output block to read from and play the audio file
        if let manager = self.audioManager,
           let fileReader = self.fileReader{
            manager.outputBlock = self.handleSpeakerQueryWithAudioFile
            fileReader.play() // tell file Reader to start filling its buffer
            manager.inputBlock = self.handleSoundData
            //manager.inputBlock = self.handleSpeakerQueryWithAudioFile
            //manager.outputBlock = self.printMax
            
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                self.runEveryInterval2()
                
            }
            
        }
        
    }
    
    //==========================================
        // MARK: Audiocard Callbacks
        // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
        // and in swift this translates to:
        // public function for starting processing of microphone data
    private func handleSoundData (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
        //printMax(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannel
        
    }

    //Mark Public Functions
    func getPrediction(fftData:[Float]){
        let baseURL = "\(SERVER_URL)/PredictOne"
        let postUrl = URL(string: "\(baseURL)")
        self.resps.removeAll()
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)

        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":fftData, "dsid":self.dsid]

        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)

        request.httpMethod = "POST"
        request.httpBody = requestBody

        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{ [self](data, response, error) in
                    if(error != nil){
                        if let res = response{
                            print("Response:\n",res)
                        }
                    }
                    else{
                        let jsonDictionary = self.convertDataToDictionary(with: data)

                        var labelResponse = jsonDictionary["prediction"]!
                        print("\(labelResponse)")
                        //receive male predictions
                        if("\(labelResponse)" == "['male']"){
                            
                            self.resps.append(labelResponse as! String)
                            self.predictionReady = true
                        }
                        //receive female predictions
                        if("\(labelResponse)" == "['female']"){
                            
                            self.resps.append(labelResponse as! String)
                            self.predictionReady = true
                        }
                        //self.displayLabelResponse(labelResponse as! String)
                        //For cleanup, We reset th resps array every time this function is called

                    }

        })
       
    
        postTask.resume() // start the task
    }
    
    //Poll responses in predictions
    func commonElementsInArray(stringArray: [String]) -> String {
        let dict = Dictionary(grouping: stringArray, by: {$0})
        let newDict = dict.mapValues({$0.count})
        return newDict.sorted(by: {$0.value > $1.value}).first?.key ?? ""
    }
    
    
    //Send prediction to UI
    func getResult()->String{
        //let countedSet = NSCountedSet(array: resps)
        //let mostFrequent = countedSet.max { countedSet.count(for: $0) < countedSet.count(for: $1)}
        //self.vc.responseLabel?.text = "\(String(describing: mostFrequent))"
        return commonElementsInArray(stringArray: resps)
        
    }
    
    //Mark - Make ModelMark our Model
    func makeModel() {
        
        // create a GET request for server to update the ML model with current data
        let baseURL = "\(SERVER_URL)/UpdateModel"
        let query = "?dsid=\(self.dsid)"
        
        let getUrl = URL(string: baseURL+query)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
              completionHandler:{(data, response, error) in
                // handle error!
                if (error != nil) {
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    if let resubAcc = jsonDictionary["resubAccuracy"]{
                        print("Resubstitution Accuracy is", resubAcc)
                    }
                }
                                                                    
        })
        
        dataTask.resume() // start the task
        
    }

    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
                try JSONSerialization.jsonObject(with: data!,
                                              options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            
            return jsonDictionary
            
        } catch {
            print("json error: \(error.localizedDescription)")
            return NSDictionary() // just return empty
        }
    }


}

