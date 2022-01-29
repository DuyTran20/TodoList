import UIKit
import ReactiveSwift

class ButtonReloadMainTableViewCell: UITableViewCell {
  
  let buttonReload = UIButton(type: .system)
  var disposables = CompositeDisposable()
  
  override func prepareForReuse() {
    super.prepareForReuse()
    disposables.dispose()
    disposables = CompositeDisposable()
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    contentView.isUserInteractionEnabled = false
    buttonReload.setTitle("Reload", for: .normal)
    buttonReload.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    buttonReload.setTitleColor(.black, for: .normal)
    buttonReload.translatesAutoresizingMaskIntoConstraints = false
    addSubview(buttonReload)
    NSLayoutConstraint.activate([
      buttonReload.topAnchor.constraint(equalTo: topAnchor),
      buttonReload.bottomAnchor.constraint(equalTo: bottomAnchor),
      buttonReload.leadingAnchor.constraint(equalTo: leadingAnchor),
      buttonReload.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
