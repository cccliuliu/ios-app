import UIKit

class MessageCell: UITableViewCell {
    
    let messageContentView = UIView()
    let backgroundImageView = UIImageView()
    
    lazy var quotedMessageView: QuotedMessageView = {
        let view = QuotedMessageView()
        quotedMessageViewIfLoaded = view
        return view
    }()
    
    lazy var checkmarkView: CheckmarkView = {
        let frame = CGRect(x: -checkmarkWidth, y: 0, width: checkmarkWidth, height: checkmarkWidth)
        let view = CheckmarkView(frame: frame)
        checkmarkViewIfLoaded = view
        return view
    }()
    
    private let checkmarkWidth: CGFloat = 16
    
    private(set) var isMultipleSelecting = false
    
    private(set) weak var checkmarkViewIfLoaded: CheckmarkView?
    private(set) weak var quotedMessageViewIfLoaded: QuotedMessageView?
    
    var viewModel: MessageViewModel?
    
    var contentFrame: CGRect {
        return backgroundImageView.frame
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if isMultipleSelecting {
            checkmarkView.status = selected ? .selected : .unselected
        }
    }
    
    func prepare() {
        messageContentView.frame = bounds
        messageContentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        messageContentView.backgroundColor = .clear
        contentView.addSubview(messageContentView)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear
        messageContentView.insertSubview(backgroundImageView, at: 0)
    }
    
    func render(viewModel: MessageViewModel) {
        self.viewModel = viewModel
        if let quotedMessageViewModel = viewModel.quotedMessageViewModel {
            if quotedMessageView.superview == nil {
                messageContentView.addSubview(quotedMessageView)
            }
            quotedMessageView.frame = viewModel.quotedMessageViewFrame
            quotedMessageView.render(viewModel: quotedMessageViewModel)
        } else {
            quotedMessageViewIfLoaded?.removeFromSuperview()
        }
    }
    
    func setMultipleSelecting(_ multipleSelecting: Bool, animated: Bool) {
        self.isMultipleSelecting = multipleSelecting
        if multipleSelecting {
            checkmarkView.status = isSelected ? .selected : .unselected
            checkmarkView.frame.size.height = contentView.bounds.height
            checkmarkView.frame.origin.x = -checkmarkWidth
            checkmarkView.autoresizingMask = .flexibleHeight
            contentView.addSubview(checkmarkView)
            checkmarkView.setNeedsLayout()
            checkmarkView.layoutIfNeeded()
            let animation = {
                self.checkmarkView.frame.origin.x = 22
                if let viewModel = self.viewModel, viewModel.style.contains(.received) {
                    self.messageContentView.frame.origin.x = self.checkmarkView.frame.maxX
                } else {
                    self.messageContentView.frame.origin.x = 0
                }
            }
            if animated {
                UIView.animate(withDuration: 0.3, animations: animation)
            } else {
                animation()
            }
        } else {
            let animation = {
                self.checkmarkView.frame.origin.x = -self.checkmarkWidth
                self.messageContentView.frame.origin.x = 0
            }
            let completion: ((Bool) -> Void) = { (_: Bool) in
                self.checkmarkViewIfLoaded?.removeFromSuperview()
            }
            if animated {
                UIView.animate(withDuration: 0.3, animations: animation, completion: completion)
            } else {
                animation()
                completion(false)
            }
        }
    }
    
}
