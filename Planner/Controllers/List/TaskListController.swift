
import UIKit
import CoreData

// контроллер для отображения списка задач
class TaskListController: UITableViewController, ActionResultDelegate {

    let dateFormatter = DateFormatter()

    // dao
    let taskDAO = TaskDaoDbImpl.current
    let categoryDAO = CategoryDaoDbImpl.current
    let priorityDAO = PriorityDaoDbImpl.current


    var searchController:UISearchController! // поисковая область, который будет добавляться поверх таблицы задач


    // секции таблицы
    let quickTaskSection = 0
    let taskListSection = 1

    let sectionCount = 2 // общее кол-во секций в таблице

    var textQuickTask:UITextField! // будет хранить ссылку на текстовый компонент для создания быстрой задачи


    // для сокращения кода (необязательно)
    var taskCount:Int{
        return taskDAO.items.count
    }



    override func viewDidLoad() {
        super.viewDidLoad()

        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        setupSearchController() // инициализаия поискового компонента

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }




    // MARK: tableView

    // методы вызываются автоматически компонентом tableView

    // сколько секций нужно отображать в таблице
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }

    // сколько будет записей в каждой секции
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch section {
        case quickTaskSection:
            return 1 // для первой секции, где можно быстро создать новую задачу
        case taskListSection:
            // этот метод вызывается перед тем, как начать показывать строки, поэтому здесь устанавливаем нужный массив (что именно отображать)
            return taskCount // кол-во записей для отображения (столько раз будет вызываться метод tableView для отображения)
        default:
            return 0
        }

    }



    // отображение данных в строке
    // метод также вызывается автоматически компонентом TableView
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch indexPath.section {
        case quickTaskSection: // в этой секции всегда будет одна ячейка - для добавления новой задачи
            // находим компонент ячейки для отображения данных
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellQuickTask", for: indexPath) as? QuickTaskCell else{
                fatalError("fatal error with cell")
            }

            textQuickTask = cell.textQuickTask
            textQuickTask.placeholder = "Введите название задачи"

            return cell

        case taskListSection: // в этой секции - список задач

            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cellTask", for: indexPath) as? TaskListCell else{
                fatalError("cell type")
            }

            let task = taskDAO.items[indexPath.row]

            cell.labelTaskName.text = task.name


            cell.labelTaskCategory.text = (task.category?.name ?? "(без категории)")
            cell.labelTaskCategory.textColor = UIColor.lightGray


            // задаем цвет по приоритету
            if let priority = task.priority{

                switch priority.index{
                case 1:
                    cell.labelPriority.backgroundColor = UIColor(named: "low")
                case 2:
                    cell.labelPriority.backgroundColor = UIColor(named: "normal")
                case 3:
                    cell.labelPriority.backgroundColor = UIColor(named: "high")
                default:
                    cell.labelPriority.backgroundColor = UIColor.white
                }

            }else{
                cell.labelPriority.backgroundColor = UIColor.white
            }


            cell.labelDeadline.textColor = .lightGray

            // отображать или нет иконку блокнота
            if task.info == nil || (task.info?.isEmpty)!{
                cell.buttonTaskInfo.isHidden = true // скрыть
            }else{
                cell.buttonTaskInfo.isHidden = false // показать
            }



            // текст для отображения кол-ва дней по задаче
            if let diff = task.daysLeft(){

                switch diff {
                case 0:
                    cell.labelDeadline.text = "Сегодня" // TODO: локализация
                case 1:
                    cell.labelDeadline.text = "Завтра"
                case 0...:
                    cell.labelDeadline.text = "\(diff) дн."

                case ..<0:
                    cell.labelDeadline.textColor = .red
                    cell.labelDeadline.text = "\(diff) дн."

                default:
                    cell.labelDeadline.text = ""
                }

            }else{
                cell.labelDeadline.text = ""
            }


            // стиль для завершенных задач
            if task.completed{
                cell.labelDeadline.textColor = .lightGray
                cell.labelTaskName.textColor = .lightGray
                cell.labelTaskCategory.textColor = .lightGray
                cell.labelPriority.backgroundColor = .lightGray

                cell.buttonCompleteTask.setImage(UIImage(named: "check_green"), for: .normal) // меняем картинку

                cell.selectionStyle = .none // чтобы строка не выделялась при нажатии

                cell.buttonTaskInfo.isEnabled = false

                cell.buttonTaskInfo.imageView?.image = UIImage(named: "note_gray")


            }else{ // стиль для незавершенных задач
                cell.selectionStyle = .default
                cell.buttonTaskInfo.isEnabled = true
                cell.buttonTaskInfo.imageView?.image = UIImage(named: "note")
                cell.labelTaskName.textColor = .darkGray
                cell.buttonCompleteTask.setImage(UIImage(named: "check_gray"), for: .normal) // меняем картинку
                cell.buttonTaskInfo.isEnabled = true
            }

            return cell

        default: return UITableViewCell() // пустая ячейка

        }
    }

    // установка высоты строки
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        switch indexPath.section {
        case quickTaskSection:
            return 40
        default:
            return 60
        }


    }

    // удаление строки
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {

            deleteTask(indexPath)

        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }

    // метод отлавливает нажатие на строку
    // разрешить переход к редактированию, если задача не завершена, иначе запретить
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if taskDAO.items[indexPath.row].completed == true{ // если задача не завершена - выходим из метода
            return
        }

        // переход в контроллер для редактирования задачи
        if indexPath.section != quickTaskSection{ // чтобы не нажимали на ячейку, где быстрое создания задачи
            performSegue(withIdentifier: "UpdateTask", sender: tableView.cellForRow(at: indexPath))
        }
    }

   

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */


    // MARK: - Navigation

    // при выполнении навигации этот метод будет выполнен автоматически
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        switch segue.identifier! { // сверяем название segue (с помощью какого segue происходит навигация)
        case "UpdateTask":

            // приведение sender к типу ячейки (получаем доступ к нажатой ячейке, чтобы определить выбранную задачу)
            let selectedCell = sender as! TaskListCell

            // выбранный индекс (номер строки, на которую нажали)
            let selectedIndex = (tableView.indexPath(for: selectedCell)?.row)!

            // выбранная задача для редактирования
            let selectedTask = taskDAO.items[selectedIndex]


            // получаем доступ к целевому контроллеру
            guard let controller = segue.destination as? TaskDetailsController else { // segue.destination - целевой контроллер
                fatalError("error")
            }

            controller.title = "Редактирование" // меняем заголовок
            controller.task = selectedTask // передаем задачу в целевой контроллер
            controller.delegate = self


        case "CreateTask":

            // получаем доступ к целевому контроллеру
            guard let controller = segue.destination as? TaskDetailsController else { // segue.destination - целевой контроллер
                fatalError("error")
            }

            controller.title = "Новая задача" // меняем заголовок
            controller.task = Task(context: taskDAO.context) // передаем задачу в целевой контроллер
            controller.delegate = self

        default:
            return
        }



    }


    // MARK: ActionResultDelegate

    // может обрабатывать ответы (слушать действия) от любых контроллеров
    func done(source: UIViewController, data: Any?) {

        // если пришел ответ от TaskDetailsController
        // сохраняет новую задачу или обновляет измененную задачу
        if source is TaskDetailsController{

            // редактирование, т.е. обновление (т.к. selectedIndexPath != nil, потому что нажимали на строку для открытия окна редактирования)
            if let selectedIndexPath = tableView.indexPathForSelectedRow{ // определяем выбранную до этого строку (если была нажата какая-либо строка)

                taskDAO.save() // сохраняем измененную задачу (сохраняет все изменения)

                tableView.reloadRows(at: [selectedIndexPath], with: .fade) // обновляем ТОЛЬКО нужную строку (не всю таблицу)

            }else{ // новая задача (не обновление, а создание)

                let task = data as! Task

                createTask(task)


            }

        }


    }


    // MARK: actions



    // нажали Удалить при редактировании задачи
    @IBAction func deleteFromTaskDetails(segue: UIStoryboardSegue) {

        guard segue.source is TaskDetailsController else { // принимаем вызовы только от TaskDetailsController (для более строгого кода)
            fatalError("return from unknown source")
        }

        // проверяем идентификатор, что именно от этого segue
        if segue.identifier == "DeleteTaskFromDetails", let selectedIndexPath = tableView.indexPathForSelectedRow{ // tableView.indexPathForSelectedRow - индекс последней нажатой строки

            deleteTask(selectedIndexPath)

        }

    }

    // нажали Завершить при редактировании задачи
    @IBAction func completeFromTaskDetails(segue: UIStoryboardSegue) {

        if let selectedIndexPath = tableView.indexPathForSelectedRow{  // индекс последней нажатой строки
            completeTask(selectedIndexPath)
        }
    }

    @IBAction func tapCompleteTask(_ sender: UIButton) {

        // определяем индекс строки по нажатому компоненту
        let viewPosition = sender.convert(CGPoint.zero, to: tableView)
        let indexPath = self.tableView.indexPathForRow(at: viewPosition)!

        completeTask(indexPath)

    }

    @IBAction func tapCreateTask(_ sender: UIBarButtonItem) {

        // есть возможность реализовать любой код перед созданием задачи

        // переход в контроллер для редактирования задачи
        performSegue(withIdentifier: "CreateTask", sender: tableView)

    }



    @IBAction func quickTaskAdd(_ sender: UITextField) {

        var task = Task(context:taskDAO.context)

        // название берем из текстового компонента - удаляем лишние пробелы и если не пусто - присваиваем
        if let name = textQuickTask.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty{
            task.name = name
        }else{
            task.name = "Новая задача"
        }

        createTask(task)

        textQuickTask.text = ""
        
    }

    
    func completeTask(_ indexPath:IndexPath){


        // принимаем вызов только из TaskListCell
        guard (tableView.cellForRow(at: indexPath) as? TaskListCell) != nil else{
            fatalError("cell type")
        }

        // обновляем вид строки
        let task = taskDAO.items[indexPath.row]

        task.completed = !task.completed // меняем состояние задачи на противоположное

        taskDAO.addOrUpdate(task)

        tableView.reloadRows(at: [indexPath], with: .fade)
    }

    func createTask(_ task:Task){
        taskDAO.addOrUpdate(task)

        // индекс для того, чтобы задача вставилась в конец списка
        let indexPath = IndexPath(row: taskCount-1, section: taskListSection)

        // вставляем новую задачу в конец списка
        tableView.insertRows(at: [indexPath], with: .bottom)
    }





    // MARK: dao

    // удаляем объект и обновляет tableView
    func deleteTask(_ indexPath:IndexPath){
        let task = taskDAO.items[indexPath.row]
        taskDAO.delete(task) // удалить задачу из БД
        taskDAO.items.remove(at: indexPath.row) // удалить саму строку и объект из коллекции (массива)
        tableView.deleteRows(at: [indexPath], with: .top) // удалить строку из tableView
    }

}


// настройка searchController и обработка действия при поиске
// можно удалить, добавил для наглядности
extension TaskListController : UISearchResultsUpdating {

    // метод делегата - вызывается автоматически для каждой буквы поиска (или когда пользователь просто активирует поиск, еще не введя текст)
    func updateSearchResults(for searchController: UISearchController) {

        // не будем использовать этот метод для поиска, т.к. нам не нужно искать после каждой нажатой буквы (для больших объемов данных может подвисать)
        // будем искать только после нажатия на enter


    }

}


// обработка действия при поиске
extension TaskListController : UISearchBarDelegate {

    // добавление search bar к таблице
    func setupSearchController() {

        searchController = UISearchController(searchResultsController: nil) // searchResultsController: nil - т.к. результаты будут сразу отображаться в этом же view

        searchController.dimsBackgroundDuringPresentation = false // затемнять фон или нет, при поиске (при затменении - не будет доступно выбирать найденную запись)
        // строка поиска будет показываться только для списка (не будет переходить в другой контроллер)

        // для правильного отображения внутри таблицы, подробнее http://www.thomasdenney.co.uk/blog/2014/10/5/uisearchcontroller-and-definespresentationcontext/
        definesPresentationContext = true

        searchController.searchBar.placeholder = "Поиск по названию"
        searchController.searchBar.backgroundColor = .white

        // обработка действий поиска и работа с search bar - в этом же классе (без этих 2 строк не будет работать поиск)
//        searchController.searchResultsUpdater = self // т.к. не используем
        searchController.searchBar.delegate = self

        // сразу не показывать segmented controls для сортировки результата (такой подход связан с глюком, когда компоненты налезают друг на друга)
        searchController.searchBar.showsScopeBar = false



        // из-за бага в работе searchController - применяем разные способы добавления searchBar в зависимости от версии iOS
        if #available(iOS 11.0, *) { // если версия iOS от 11 и выше
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            tableView.tableHeaderView = searchController.searchBar
        }


    }



    // обязываем пользователя нажимать enter для поиска (чтобы не искать после каждой введенной буквы - может подвисвать для больших объемов данных)
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }

    // поиск после окончания ввода данных (нажатия на Search)
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if !(searchController.searchBar.text?.isEmpty)!{ // искать, только если есть текст
            taskDAO.search(text: searchController.searchBar.text!) // берем текст из поля поиска
            tableView.reloadData()  //  обновляем всю таблицу
        }
    }

    // нажимаем на кнопку Cancel
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchController.searchBar.text = ""
        taskDAO.getAll() // возвращаем все записи
        tableView.reloadData()
    }

    




}