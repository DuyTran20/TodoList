import ComposableArchitecture
import SwiftUI
import UIKit
import ConvertSwift
import RxCocoa

final class MainViewController: UIViewController {
  
  private let store: Store<MainState, MainAction>
  
  private let viewStore: ViewStore<ViewState, ViewAction>
  
    /// Properties
  private let disposeBag = DisposeBag()
  
  private let tableView: UITableView = UITableView()
  
  private var todos: [TodoModel] = []
  
  init(store: Store<MainState, MainAction>? = nil) {
    let unwrapStore = store ?? Store(initialState: MainState(), reducer: MainReducer, environment: MainEnvironment())
    self.store = unwrapStore
    self.viewStore = ViewStore(unwrapStore.scope(state: ViewState.init, action: MainAction.init))
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    viewStore.send(.viewDidLoad)
      // navigationView
    let buttonLogout = UIButton(type: .system)
    buttonLogout.setTitle("Logout", for: .normal)
    buttonLogout.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
    if #available(iOS 14.0, *) {
      buttonLogout.setTitleColor(UIColor(Color.blue), for: .normal)
    } else {
        // Fallback on earlier versions
    }
    let rightBarButtonItem = UIBarButtonItem(customView: buttonLogout)
    
    let buttonCount = UIButton(type: .system)
    buttonCount.setTitle("+ 0 -", for: .normal)
    let leftBarButtonItem = UIBarButtonItem(customView: buttonCount)
    
      // tableView
    view.addSubview(tableView)
    tableView.register(MainTableViewCell.self)
    tableView.register(ButtonReloadMainTableViewCell.self)
    tableView.register(CreateTitleMainTableViewCell.self)
    tableView.showsVerticalScrollIndicator = false
    tableView.showsHorizontalScrollIndicator = false
    tableView.delegate = self
    tableView.dataSource = self
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.frame = view.frame.insetBy(dx: 10, dy: 10)
    tableView.isUserInteractionEnabled = true
    
    navigationController?.navigationBar.prefersLargeTitles = true
    navigationItem.largeTitleDisplayMode = .always
    navigationItem.rightBarButtonItem = rightBarButtonItem
    navigationItem.leftBarButtonItem = leftBarButtonItem
    
      //bind view to viewstore
    buttonLogout.rx.tap
      .map{ViewAction.logout}
      .subscribe(viewStore.action)
      .disposed(by: disposeBag)
    
    buttonCount.rx.tap
      .map{ViewAction.setNavigation(isActive: true)}
      .subscribe(viewStore.action)
      .disposed(by: disposeBag)
    
      //bind viewstore to view
    viewStore.publisher.todos
      .subscribe(onNext: { [weak self] todos in
        guard let self = self else { return }
        self.todos = todos
        self.tableView.reloadData()
      })
      .disposed(by: disposeBag)
    
    viewStore.publisher.todos
      .map {$0.count.toString() + " Todos"}
      .bind(to: navigationItem.rx.title)
      .disposed(by: disposeBag)
    
    self.store
      .scope(state: \.optionalCounterState, action: MainAction.counterAction)
      .ifLet(
        then: { [weak self] store in
          self?.navigationController?.pushViewController(
            CounterViewController(store: store), animated: true)
        },
        else: { [weak self] in
          guard let self = self else { return }
          self.navigationController?.popToViewController(self, animated: true)
        }
      )
      .disposed(by: disposeBag)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !self.isMovingToParent {
      self.viewStore.send(.setNavigation(isActive: false))
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewStore.send(.viewWillAppear)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    viewStore.send(.viewWillDisappear)
  }
  
  deinit {
    viewStore.send(.viewDeinit)
  }
  
}

extension MainViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 3
  }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0:
      return 1
    case 1:
      return 1
    case 2:
      return todos.count
    default:
      return 0
    }
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case 0:
      let cell = tableView.dequeueReusableCell(ButtonReloadMainTableViewCell.self, for: indexPath)
      cell.selectionStyle = .none
      viewStore.publisher.isLoading
        .subscribe(onNext: { value in
          cell.buttonReload.isHidden = value
          cell.activityIndicator.isHidden = !value
        })
        .disposed(by: cell.disposeBag)
      viewStore.publisher.networkStatus
        .subscribe(onNext: { value in
          cell.networkStatus.text = value.description
          if #available(iOS 14.0, *) {
            cell.networkStatus.textColor = value == .online ? UIColor(Color.green) : UIColor(Color.gray)
          } else {
              // Fallback on earlier versions
          }
        })
        .disposed(by: cell.disposeBag)
      cell.buttonReload.rx.tap
        .map{ViewAction.getTodo}
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      return cell
    case 1:
      let cell = tableView.dequeueReusableCell(CreateTitleMainTableViewCell.self, for: indexPath)
      viewStore.publisher.title
        .bind(to: cell.titleTextField.rx.text)
        .disposed(by: cell.disposeBag)
      viewStore.publisher.title.isEmpty
        .subscribe(onNext: { value in
          if #available(iOS 14.0, *) {
            cell.buttonCreate.setTitleColor(value ? UIColor(Color.gray) : UIColor(Color.green), for: .normal)
          } else {
              // Fallback on earlier versions
          }
        })
        .disposed(by: cell.disposeBag)
      cell.buttonCreate
        .rx.tap
        .map {ViewAction.createTodo}
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      cell.titleTextField
        .rx.text.orEmpty
        .compactMap{$0}
        .map(ViewAction.changeTextFieldTitle)
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      return cell
    case 2:
      let cell = tableView.dequeueReusableCell(MainTableViewCell.self, for: indexPath)
      let todo = todos[indexPath.row]
      cell.bind(todo)
      cell.deleteButton
        .rx.tap
        .map{ViewAction.deleteTodo(todo)}
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      cell.tapGesture
        .rx.event
        .map {_ in ViewAction.toggleTodo(todo)}
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      return cell
    default:
      let cell = tableView.dequeueReusableCell(MainTableViewCell.self, for: indexPath)
      return cell
    }
  }
}

extension MainViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 60
  }
}

fileprivate struct ViewState: Equatable {
  var title: String = ""
  var todos: [TodoModel] = []
  var isLoading: Bool = false
  var networkStatus: NetworkStatus = .none
  init(state: MainState) {
    self.title = state.title
    self.isLoading = state.isLoading
    self.networkStatus = state.networkStatus
    self.todos = state.todos
  }
}

fileprivate enum ViewAction: Equatable {
  case viewDidLoad
  case viewWillAppear
  case viewWillDisappear
  case viewDeinit
  case none
  case getTodo
  case toggleTodo(TodoModel)
  case createTodo
  case updateTodo(TodoModel)
  case deleteTodo(TodoModel)
  case logout
  case changeTextFieldTitle(String)
  case setNavigation(isActive: Bool)
    /// init ViewAction
    /// - Parameter action: MainAction
  init(action: MainAction) {
    self = .none
  }
}

fileprivate extension MainAction {
  init(action: ViewAction) {
    switch action {
    case .viewDidLoad:
      self = .viewDidLoad
    case .viewWillAppear:
      self = .viewWillAppear
    case .viewWillDisappear:
      self = .viewWillDisappear
    case .getTodo:
      self = .getTodo
    case .toggleTodo(let todo):
      self = .toggleTodo(todo)
    case .createTodo:
      self = .viewCreateTodo
    case .deleteTodo(let todo):
      self = .deleteTodo(todo)
    case .logout:
      self = .logout
    case .changeTextFieldTitle(let text):
      self = .changeTextFieldTitle(text)
    case .setNavigation(isActive: let isActive):
      self = .setNavigation(isActive: isActive)
    case .viewDeinit:
      self = .viewDeinit
    default:
      self = .none
    }
  }
}
