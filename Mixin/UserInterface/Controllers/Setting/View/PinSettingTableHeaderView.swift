import UIKit

class PinSettingTableHeaderView: UIView {
    
    @IBOutlet weak var textLabel: TextLabel!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelTrailingConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textLabel.delegate = self
        textLabel.textColor = .accessoryText
        textLabel.lineSpacing = 10
        textLabel.linkColor = .theme
        let text = R.string.localizable.setting_pin_hint()
        textLabel.text = text
        let linkRange = (text as NSString).range(of: R.string.localizable.action_learn_more(), options: [.backwards, .caseInsensitive])
        if linkRange.location != NSNotFound && linkRange.length != 0 {
            textLabel.linksMap = [linkRange: URL.pinTIP]
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let textLabelWidthToTypeset = size.width
            - textLabelLeadingConstraint.constant
            - textLabelTrailingConstraint.constant
        let textLabelHeight = textLabel.typeset(width: textLabelWidthToTypeset).height
        let height = imageViewTopConstraint.constant
            + (imageView.image?.size.height ?? 68)
            + textLabelTopConstraint.constant
            + textLabelHeight
            + textLabelBottomConstraint.constant
        return CGSize(width: size.width, height: ceil(height))
    }
    
}

extension PinSettingTableHeaderView: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        
    }

}
