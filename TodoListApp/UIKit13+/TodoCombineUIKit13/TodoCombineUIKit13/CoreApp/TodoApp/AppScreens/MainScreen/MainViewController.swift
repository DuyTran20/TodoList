import ComposableArchitecture
import SwiftUI
import UIKit
import ConvertSwift
import Combine
import CombineCocoa

final class MainViewController: UIViewController {
  
  private let store: Store<MainState, MainAction>
  
  private let viewStore: ViewStore<ViewState, ViewAction>
  
  /// Properties
  private var cancellables: Set<AnyCancellable> = []
  
  private let tableView: UITableView = UITableView()
  
  private var todos: IdentifiedArrayOf<TodoModel> = []
  
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
    buttonLogout.setTitleColor(UIColor(Color.blue), for: .normal)
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
    buttonLogout.tapPublisher
      .map{ViewAction.logout}
      .subscribe(viewStore.action)
      .store(in: &cancellables)
    
    buttonCount.tapPublisher
      .map{ViewAction.setNavigation(isActive: true)}
      .subscribe(viewStore.action)
      .store(in: &cancellables)
    
    //bind viewstore to view
    viewStore.publisher.todos
      .sink { [weak self] todos in
        guard let self = self else {
          return
        }
        self.todos = todos
        self.tableView.reloadData()
      }
      .store(in: &cancellables)
    
    viewStore.publisher.todos
      .map {$0.count.toString() + " Todos"}
      .assign(to: \.navigationItem.title, on: self)
      .store(in: &cancellables)
    
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
      .store(in: &self.cancellables)
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
        .sink(receiveValue: { value in
          cell.buttonReload.isHidden = value
          cell.activityIndicator.isHidden = !value
        })
        .store(in: &cell.cancellables)
      viewStore.publisher.networkStatus
        .sink { networkStatus in
          cell.networkStatus.text = networkStatus.description
          cell.networkStatus.textColor = networkStatus == .online ? UIColor(Color.green) : UIColor(Color.gray)
        }
        .store(in: &cell.cancellables)
      cell.buttonReload.tapPublisher
        .map{ViewAction.getTodo}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
      return cell
    case 1:
      let cell = tableView.dequeueReusableCell(CreateTitleMainTableViewCell.self, for: indexPath)
      viewStore.publisher.title
        .map {$0}
        .assign(to: \.text, on: cell.titleTextField)
        .store(in: &cell.cancellables)
      viewStore.publisher.title.isEmpty
        .sink(receiveValue: { value in
          cell.buttonCreate.setTitleColor(value ? UIColor(Color.gray) : UIColor(Color.green), for: .normal)
        })
        .store(in: &cell.cancellables)
      cell.buttonCreate.tapPublisher
        .map {ViewAction.createTodo}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
      cell.titleTextField.textPublisher
        .compactMap{$0}
        .map{ViewAction.changeTextFieldTitle($0)}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
      return cell
    case 2:
      let cell = tableView.dequeueReusableCell(MainTableViewCell.self, for: indexPath)
      let todo = todos[indexPath.row]
      cell.bind(todo)
      cell.deleteButton.tapPublisher
        .map{ViewAction.deleteTodo(todo)}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
      cell.tapGesture.tapPublisher
        .map {_ in ViewAction.toggleTodo(todo)}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
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

struct MainViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = MainViewController()
    UIViewRepresented(makeUIView: { _ in vc.view })
  }
}

fileprivate struct ViewState: Equatable {
  var title: String = ""
  var todos: IdentifiedArrayOf<TodoModel> = []
  var isLoading: Bool = false
  var networkStatus: NetworkStatus = .none
  init(state: MainState) {
    self.title = state.title
    self.isLoading = state.isLoading
    self.networkStatus = state.networkStatus
    if let results = state.results {
      for item in Array(results).asArrayTodo() {
        self.todos.append(item)
      }
    }
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
