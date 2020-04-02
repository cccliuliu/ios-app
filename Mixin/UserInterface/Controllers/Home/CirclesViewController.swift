import UIKit
import MixinServices

class CirclesViewController: UIViewController {
    
    @IBOutlet weak var toggleCirclesButton: UIButton!
    @IBOutlet weak var tableBackgroundView: UIView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var showTableViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideTableViewConstraint: NSLayoutConstraint!
    
    private let tableFooterButton = UIButton()
    
    private lazy var deleteAction = UITableViewRowAction(style: .destructive,
                                                         title: Localized.MENU_DELETE,
                                                         handler: tableViewCommitDeleteAction(action:indexPath:))
    private lazy var editAction: UITableViewRowAction = {
        let action = UITableViewRowAction(style: .normal,
                                          title: R.string.localizable.menu_edit(),
                                          handler: tableViewCommitEditAction(action:indexPath:))
        action.backgroundColor = .theme
        return action
    }()
    
    private weak var editNameController: UIAlertController?
    
    private var embeddedCircles = CircleDAO.shared.embeddedCircles()
    private var userCircles: [CircleItem] = []
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tableHeaderView = InfiniteTopView()
        tableHeaderView.frame.size.height = 0
        tableView.tableHeaderView = tableHeaderView
        tableView.dataSource = self
        tableView.delegate = self
        tableFooterButton.backgroundColor = .clear
        DispatchQueue.global().async {
            self.reloadUserCirclesFromLocalStorage(completion: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(circleConversationsDidChange), name: CircleConversationDAO.circleConversationsDidChangeNotification, object: nil)
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if let parent = parent as? HomeViewController {
            let action = #selector(HomeViewController.toggleCircles(_:))
            tableFooterButton.addTarget(parent, action: action, for: .touchUpInside)
            toggleCirclesButton.addTarget(parent, action: action, for: .touchUpInside)
        }
    }
    
    @IBAction func newCircleAction(_ sender: Any) {
        let addCircle = R.string.localizable.circle_action_add()
        let add = R.string.localizable.action_add()
        presentEditNameController(title: addCircle, actionTitle: add, currentName: nil) { (alert) in
            guard let name = alert.textFields?.first?.text else {
                return
            }
            let vc = CircleEditorViewController.instance(intent: .create(name: name))
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func circleConversationsDidChange() {
        DispatchQueue.global().async {
            self.reloadUserCirclesFromLocalStorage(completion: nil)
        }
    }
    
    func setTableViewVisible(_ visible: Bool, animated: Bool, completion: (() -> Void)?) {
        if visible {
            reloadUserCircleFromRemote()
            showTableViewConstraint.priority = .defaultHigh
            hideTableViewConstraint.priority = .defaultLow
        } else {
            showTableViewConstraint.priority = .defaultLow
            hideTableViewConstraint.priority = .defaultHigh
        }
        let work = {
            self.view.layoutIfNeeded()
            self.tableBackgroundView.alpha = visible ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: work) { (_) in
                completion?()
            }
        } else {
            work()
            completion?()
        }
    }
    
}

extension CirclesViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = Section(rawValue: section)!
        switch section {
        case .embedded:
            return embeddedCircles.count
        case .user:
            return userCircles.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.circle, for: indexPath)!
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .embedded:
            let circle = embeddedCircles[indexPath.row]
            cell.titleLabel.text = "Mixin"
            cell.subtitleLabel.text = R.string.localizable.circle_conversation_count_all()
            cell.unreadMessageCountLabel.text = "\(circle.unreadCount)"
            cell.circleImageView.image = R.image.ic_circle_all()
        case .user:
            let circle = userCircles[indexPath.row]
            cell.titleLabel.text = circle.name
            cell.subtitleLabel.text = R.string.localizable.circle_conversation_count("\(circle.conversationCount)")
            cell.unreadMessageCountLabel.text = "\(circle.unreadCount)"
            cell.circleImageView.image = R.image.ic_circle_user()
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
}

extension CirclesViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == Section.user.rawValue
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        [deleteAction, editAction]
    }
    
}

extension CirclesViewController {
    
    private enum Section: Int, CaseIterable {
        case embedded = 0
        case user
    }
    
    private func tableViewCommitEditAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let circle = userCircles[indexPath.row]
        let editName = R.string.localizable.circle_action_edit_name()
        let change = R.string.localizable.dialog_button_change()
        let editConversation = R.string.localizable.circle_action_edit_conversations()
        let cancel = R.string.localizable.dialog_button_cancel()
        
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: editName, style: .default, handler: { (_) in
            self.presentEditNameController(title: editName, actionTitle: change, currentName: circle.name) { (alert) in
                guard let name = alert.textFields?.first?.text else {
                    return
                }
                self.editCircle(with: circle.circleId, name: name)
            }
        }))
        sheet.addAction(UIAlertAction(title: editConversation, style: .default, handler: { (_) in
            let vc = CircleEditorViewController.instance(intent: .update(id: circle.circleId))
            self.present(vc, animated: true, completion: nil)
        }))
        sheet.addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
        
        present(sheet, animated: true, completion: nil)
    }
    
    private func tableViewCommitDeleteAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let circle = userCircles[indexPath.row]
        let delete = R.string.localizable.circle_action_delete()
        let cancel = R.string.localizable.dialog_button_cancel()
        let sheet = UIAlertController(title: circle.name, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: delete, style: .destructive, handler: { (_) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.window)
            CircleAPI.shared.delete(id: circle.circleId) { (result) in
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        CircleDAO.shared.delete(circleId: circle.circleId)
                        self.reloadUserCirclesFromLocalStorage {
                            hud.set(style: .notification, text: R.string.localizable.toast_deleted())
                        }
                    }
                case .failure(let error):
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
            }
        }))
        sheet.addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func presentEditNameController(title: String, actionTitle: String, currentName: String?, handler: @escaping (UIAlertController) -> Void) {
        let cancel = R.string.localizable.dialog_button_cancel()
        
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.text = currentName
            textField.addTarget(self, action: #selector(self.alertInputChangedAction(_:)), for: .editingChanged)
        }
        alert.addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
        let action = UIAlertAction(title: actionTitle, style: .default, handler: { [unowned alert] _ in
            handler(alert)
        })
        action.isEnabled = false
        alert.addAction(action)
        
        self.editNameController = alert
        present(alert, animated: true, completion: {
            alert.textFields?.first?.selectAll(nil)
        })
    }
    
    @objc private func alertInputChangedAction(_ sender: UITextField) {
        guard let controller = editNameController, let text = controller.textFields?.first?.text else {
            return
        }
        controller.actions[1].isEnabled = !text.isEmpty
    }
    
    private func editCircle(with circleId: String, name: String) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.window)
        CircleAPI.shared.update(id: circleId, name: name, completion: { result in
            switch result {
            case .success(let circle):
                DispatchQueue.global().async {
                    CircleDAO.shared.insertOrReplace(circle: circle)
                    self.reloadUserCirclesFromLocalStorage() {
                        hud.set(style: .notification, text: R.string.localizable.toast_saved())
                    }
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        })
    }
    
    private func reloadUserCircleFromRemote() {
        CircleAPI.shared.circles { [weak self] (result) in
            guard case let .success(circles) = result else {
                return
            }
            DispatchQueue.global().async {
                CircleDAO.shared.insertOrReplace(circles: circles)
                self?.reloadUserCirclesFromLocalStorage(completion: nil)
            }
        }
    }
    
    private func reloadUserCirclesFromLocalStorage(completion: (() -> Void)?) {
        let circles = CircleDAO.shared.circles()
        DispatchQueue.main.sync {
            self.userCircles = circles
            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()
            self.tableView.tableFooterView = nil
            let height = self.tableView.frame.height - self.tableView.contentSize.height
            self.tableFooterButton.frame.size.height = height
            self.tableView.tableFooterView = self.tableFooterButton
            completion?()
        }
    }
    
}
