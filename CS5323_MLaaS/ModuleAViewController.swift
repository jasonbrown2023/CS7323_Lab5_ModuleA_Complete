
import UIKit
import AVFoundation



class ModuleAViewController: UIViewController, AVAudioPlayerDelegate, AVAudioRecorderDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    
    //Mark Picker Functions
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return gender.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return gender[row]
    }
    
    
    

    //Mark properties
    @IBOutlet weak var predictLabel: UIButton!
    
    
    @IBAction func predictButton(_ sender: UIButton) {
        self.speechModel?.play2(withFps:20)
        speechModel?.startProcesingAudioFileForPlayback2(withFps:20) //Send test data
        if(self.speechModel?.predictionReady==true){
            self.responseLabel.text = "\(String(describing: self.speechModel?.getResult()))"
        }
    }

    //Precitions results
    @IBOutlet weak var responseLabel: UILabel!
    
    //Picker variables
    let gender = ["Male", "Female"]
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var postButton: UIButton!
    
    @IBOutlet weak var segmentControl: UISegmentedControl!
    @IBOutlet weak var genderPicker: UIPickerView!
    
    @IBOutlet weak var makeModelLabel: UIButton!
    
    @IBOutlet weak var playLabel: UIButton!
    
    var soundRecorder = AVAudioRecorder()
    var soundPlayer = AVAudioPlayer()
    
    var speechModel:SpeechModel? = nil
    var genderSelection: Int = 0
    var genderLabel = ""
    
    //Setup UI Configuration
    @IBAction func sceneSelector(_ sender: UISegmentedControl) {
        switch segmentControl.selectedSegmentIndex
        {
        case 0:
            makeModelLabel.isHidden = false
            responseLabel.isHidden = true
            predictLabel.isHidden = true
            genderPicker.isHidden = false
            recordButton.isHidden = false
            postButton.isHidden = false
            playLabel.isHidden = false
            responseLabel.isHidden = true
            
        case 1:
            predictLabel.isHidden = false
            responseLabel.isHidden = false
            genderPicker.isHidden = true
            recordButton.isHidden = false
            postButton.isHidden = true
            playLabel.isHidden = false
            responseLabel.isHidden = false
            makeModelLabel.isHidden = true

            
        default:
            break;
        }
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.speechModel = SpeechModel()
        speechModel?.setupRecorder()
        genderPicker.dataSource = self
        genderPicker.delegate = self
        genderPicker.isHidden = false
        predictLabel.isHidden = true
        responseLabel.isHidden = true

        
    }
    
        
    //Mark Action Area
    @IBAction func recordSound(_ sender: Any) {
        //Check if recording is happening
        if(speechModel?.cflag==false){
            
            // Update UI for recording state
            self.recordButton?.setTitle("stop", for: .normal)
            //genderPicker.isHidden = true
            self.genderSelection = genderPicker.selectedRow(inComponent: 0)
            //setup label to be tagged with recording
            if(self.genderSelection==1){
                genderLabel="female"
                
            }
            //setup label to be tagged with recording
            if(self.genderSelection==0){
                self.genderLabel = "male"
            }
            print(self.genderSelection)
            speechModel?.recordSound()
        }
        else{
            //if not recording, well record
            //genderPicker.isHidden = false
            speechModel?.recordSound()
            // Update UI for non-recording state
            self.recordButton?.setTitle("Record", for: .normal)
        }
       
    }
    
   
    
    @IBAction func playSound(_ sender: Any) {
        //Call play recording function
        self.speechModel?.playSound()
        
        
    }
    
    @IBAction func postSound(_ sender: Any) {
        //Call play post function
        
        self.speechModel?.play(withFps:20, label:self.genderLabel)
        self.speechModel?.startProcesingAudioFileForPlayback(withFps: 20, label:self.genderLabel)
        //speechModel?.makeModel()
    }
    
    @IBAction func makeModelButton(_ sender: UIButton) {
        self.speechModel?.makeModel()
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}



