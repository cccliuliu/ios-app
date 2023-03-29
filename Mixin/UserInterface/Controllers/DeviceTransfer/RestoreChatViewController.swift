import UIKit
import MixinServices

class RestoreChatViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private var isUsernameJustInitialized = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(R.nib.restoreChatTableViewCell)
        tableView.tableHeaderView = UIView()
        tableView.tableFooterView = UIView()
    }
    
    @IBAction func skipButton(_ sender: Any) {
        Logger.general.info(category: "RestoreChatViewController", message: "Restoration skipped")
        AppGroupUserDefaults.Account.canRestoreChat = false
        AppGroupUserDefaults.Account.canRestoreMedia = false
        AppDelegate.current.mainWindow.rootViewController = makeInitialViewController(isUsernameJustInitialized: isUsernameJustInitialized)
    }
    
    class func instance(isUsernameJustInitialized: Bool) -> UIViewController {
        let vc = RestoreChatViewController()
        vc.isUsernameJustInitialized = isUsernameJustInitialized
        let navigationController = LoneBackButtonNavigationController(rootViewController: vc)
        return navigationController
    }
}

extension RestoreChatViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.restore_chat, for: indexPath)!
        cell.imageView?.tintColor = R.color.icon_tint()
        if indexPath.section == 0 {
            cell.titleLabel.text = R.string.localizable.restore_from_another_phone()
            cell.detailLabel.text = R.string.localizable.transfer_from_phone_hint()
            cell.imageView?.image = R.image.setting.ic_chat_restore_phone()
        } else {
            cell.titleLabel.text = R.string.localizable.restore_from_icloud()
            cell.detailLabel.text = R.string.localizable.restore_chat_from_icloud()
            cell.imageView?.image = R.image.setting.ic_chat_restore_cloud()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc: UIViewController
        if indexPath.section == 0 {
            vc = RestoreFromPhoneViewController.instance()
        } else {
            vc = RestoreFromCloudViewController.instance(isUsernameJustInitialized: isUsernameJustInitialized)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        10
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        0
    }
    
}
