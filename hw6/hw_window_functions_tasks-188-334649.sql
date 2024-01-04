/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "06 - Оконные функции".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters
/*
1. Сделать расчет суммы продаж нарастающим итогом по месяцам с 2015 года 
(в рамках одного месяца он будет одинаковый, нарастать будет в течение времени выборки).
Выведите: id продажи, название клиента, дату продажи, сумму продажи, сумму нарастающим итогом

Пример:
-------------+----------------------------
Дата продажи | Нарастающий итог по месяцу
-------------+----------------------------
 2015-01-29   | 4801725.31
 2015-01-30	 | 4801725.31
 2015-01-31	 | 4801725.31
 2015-02-01	 | 9626342.98
 2015-02-02	 | 9626342.98
 2015-02-03	 | 9626342.98
Продажи можно взять из таблицы Invoices.
Нарастающий итог должен быть без оконной функции.
*/

select 
i.InvoiceID,
c.CustomerName,
i.InvoiceDate,
Sum = o.UnitPrice * o.PickedQuantity,
TotalSum = (
		select 
		sum2 = sum(o2.UnitPrice * o2.PickedQuantity)
		from Sales.Invoices i2
		join Sales.OrderLines o2 on i2.OrderID = o2.OrderID
		where month(i2.InvoiceDate) <= month(i.InvoiceDate)
)
from Sales.Invoices i
join Sales.OrderLines o on i.OrderID = o.OrderID
join Sales.Customers c on c.CustomerID = i.CustomerID
where i.InvoiceDate >= '2015-01-01'
order by i.InvoiceID

/*
2. Сделайте расчет суммы нарастающим итогом в предыдущем запросе с помощью оконной функции.
   Сравните производительность запросов 1 и 2 с помощью set statistics time, io on
*/

select 
i.InvoiceID,
c.CustomerName,
i.InvoiceDate,
Sum = o.UnitPrice * o.PickedQuantity,
TotalSum = sum(o.UnitPrice * o.PickedQuantity) over (order by DATEPART(month, i.InvoiceDate))
from Sales.Invoices i
join Sales.OrderLines o on i.OrderID = o.OrderID
join Sales.Customers c on c.CustomerID = i.CustomerID
where i.InvoiceDate >= '2015-01-01'
order by i.InvoiceID

/*
3. Вывести список 2х самых популярных продуктов (по количеству проданных) 
в каждом месяце за 2016 год (по 2 самых популярных продукта в каждом месяце).
*/

select 
	t.InvoiceDate as MonthNumber,
	t.StockItemName as Name,
	t.TotalQuantity as TotalCount
	
from 
	(
		select
		ws.StockItemID,
		ws.StockItemName,
		TotalQuantity = sum(ol.Quantity),
		InvoiceDate = month(i.InvoiceDate),
		Rank = DENSE_RANK() over (partition by DATEPART(month, i.InvoiceDate) order by sum(ol.Quantity) desc)
		from Sales.OrderLines ol
		join Warehouse.StockItems ws on ws.StockItemID = ol.StockItemID
		join Sales.Invoices i on i.OrderID = ol.OrderID
		where YEAR(i.InvoiceDate) = 2016
		group by ws.StockItemID, ws.StockItemName, month(i.InvoiceDate)
	) t
where t.Rank <= 2
order by MonthNumber, TotalCount
/*
4. Функции одним запросом
Посчитайте по таблице товаров (в вывод также должен попасть ид товара, название, брэнд и цена):
* пронумеруйте записи по названию товара, так чтобы при изменении буквы алфавита нумерация начиналась заново
* посчитайте общее количество товаров и выведете полем в этом же запросе
* посчитайте общее количество товаров в зависимости от первой буквы названия товара
* отобразите следующий id товара исходя из того, что порядок отображения товаров по имени 
* предыдущий ид товара с тем же порядком отображения (по имени)
* названия товара 2 строки назад, в случае если предыдущей строки нет нужно вывести "No items"
* сформируйте 30 групп товаров по полю вес товара на 1 шт

Для этой задачи НЕ нужно писать аналог без аналитических функций.
*/

select 
ws.StockItemID,
ws.StockItemName,
ps.SupplierName,
ws.UnitPrice,
Number = ROW_NUMBER() over (order by ws.StockItemName),
TotalCount = count(ws.StockItemID) over (),
TotalOnFirstLetter = count(ws.StockItemID) over(partition by lower(left(ws.StockItemName, 1))),
Previous = lag(ws.StockItemID, 1) over (order by ws.StockItemName),
Previous2 = 
case when (lag(ws.StockItemID, 2) over (order by ws.StockItemName)) is null then 'No items'
else convert(nvarchar(12), (lag(ws.StockItemID, 2) over (order by ws.StockItemName))) end,
WeightGroup = ntile(30) over (partition by ws.TypicalWeightPerUnit order by ws.StockItemName)
from  Warehouse.StockItems ws 
join Purchasing.Suppliers ps on ws.SupplierID = ps.SupplierID
order by ws.StockItemName

/*
5. По каждому сотруднику выведите последнего клиента, которому сотрудник что-то продал.
   В результатах должны быть ид и фамилия сотрудника, ид и название клиента, дата продажи, сумму сделки.
*/

;with cte (LastInvoiceID)
as
(
	select 
	LastInvoiceID = LAST_VALUE(i.InvoiceID) over (partition by i.SalespersonPersonID order by i.InvoiceID asc rows between unbounded preceding and unbounded following)
	from 
	Sales.Invoices i
),
cte2 (InvoiceID, InvoiceSum)
as
(
	select
	InvoiceID = i.InvoiceID,
	InvoiceSum = sum(ol.UnitPrice * ol.PickedQuantity)
	from Sales.Invoices i
	join Sales.OrderLines ol on ol.OrderID = i.OrderID
	group by i.InvoiceID
)
select
InvoiceID = i.InvoiceID,
SalespersonPersonID = i.SalespersonPersonID,
CustomerID = i.CustomerID,
InvoiceDate = i.InvoiceDate,
InvoiceSum = cte2.InvoiceSum
from Sales.Invoices i
join cte2 on cte2.InvoiceID = i.InvoiceID
where i.InvoiceID in (select LastInvoiceID from cte)

/*
6. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

;with cte (CustomerID, StockItemID, UnitPrice, InvoiceDate, Rank)
as
(
	select 
	CustomerID = c.CustomerID,
	StockItemID = ol.StockItemID,
	UnitPrice = ol.UnitPrice,
	InvoiceDate = i.InvoiceDate,
	Rank = DENSE_RANK() over (partition by c.CustomerID order by ol.UnitPrice desc)
	from Sales.Customers c
	join Sales.Invoices i on i.CustomerID = c.CustomerID
	join Sales.OrderLines ol on ol.OrderID = i.OrderID
)
--ид клиета, его название, ид товара, цена, дата покупки
select
CustomerID = cte.CustomerID,
CustomerName = p.FullName,
StockItemID = cte.StockItemID,
UnitPrice = cte.UnitPrice,
InvoiceDate = cte.InvoiceDate,
Rank = cte.Rank
from
cte
join Application.People p on cte.CustomerID = p.PersonID
where cte.Rank <= 2
order by CustomerID asc, Rank asc, InvoiceDate desc