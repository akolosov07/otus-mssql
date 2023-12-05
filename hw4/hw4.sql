/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "03 - Подзапросы, CTE, временные таблицы".

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
-- Для всех заданий, где возможно, сделайте два варианта запросов:
--  1) через вложенный запрос
--  2) через WITH (для производных таблиц)
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Выберите сотрудников (Application.People), которые являются продажниками (IsSalesPerson), 
и не сделали ни одной продажи 04 июля 2015 года. 
Вывести ИД сотрудника и его полное имя. 
Продажи смотреть в таблице Sales.Invoices.
*/

select ap.PersonID, ap.FullName from Application.People ap
where ap.IsSalesperson = 1
and ap.PersonID not in
(select si.SalespersonPersonID from Sales.Invoices si
where si.InvoiceDate = '20150704')

with cte (PersonID, FullName)
as
(
	select ap.PersonID, ap.FullName from Application.People ap
	where ap.IsSalesperson = 1
)
select * from cte
where cte.PersonID not in
(select si.SalespersonPersonID from Sales.Invoices si
where si.InvoiceDate = '20150704')

/*
2. Выберите товары с минимальной ценой (подзапросом). Сделайте два варианта подзапроса. 
Вывести: ИД товара, наименование товара, цена.
*/

select so.StockItemID,
(select ws.StockItemName from Warehouse.StockItems ws where ws.StockItemID = so.StockItemID) as StockItemName,
min(so.UnitPrice) as MinPrice from Sales.OrderLines so
group by so.StockItemID
order by MinPrice asc

;with cte (StockItemID, MinPrice)
as
(
	select so.StockItemID,
	min(so.UnitPrice) as MinPrice from Sales.OrderLines so
	group by so.StockItemID
)
select cte.StockItemID, ws.StockItemName, cte.MinPrice
from cte
join Warehouse.StockItems ws on ws.StockItemID = cte.StockItemID
order by cte.MinPrice asc

/*
3. Выберите информацию по клиентам, которые перевели компании пять максимальных платежей 
из Sales.CustomerTransactions. 
Представьте несколько способов (в том числе с CTE). 
*/

select 
sc.CustomerID, 
sc.CustomerName,
(select max(tr.TransactionAmount) from Sales.CustomerTransactions tr where sc.CustomerID = tr.CustomerID)
from Sales.Customers sc
where sc.CustomerID in
(select top 5 with ties 
t.CustomerID
from Sales.CustomerTransactions t
order by t.TransactionAmount desc)

;with cte (CustomerID, MaxTransactionAmount)
as
(
	select tr.CustomerID as CustomerID, max(tr.TransactionAmount) as MaxTransactionAmount 
	from Sales.CustomerTransactions tr
	group by tr.CustomerID
)
select top 5
t.CustomerID, 
sc.CustomerName,
cte.MaxTransactionAmount as MaxTransactionAmount
from Sales.CustomerTransactions t
join cte on cte.CustomerID = t.CustomerID
join Sales.Customers sc on sc.CustomerID = t.CustomerID
order by t.TransactionAmount desc

/*
4. Выберите города (ид и название), в которые были доставлены товары, 
входящие в тройку самых дорогих товаров, а также имя сотрудника, 
который осуществлял упаковку заказов (PackedByPersonID).
*/

select 
sc.DeliveryCityID as DeliveryCityID,
ac.CityName as CityName,
si.PackedByPersonID as PackedByPersonID, 
ap.FullName as PackedByPerson
from Sales.Orders sor
join Sales.Invoices si on sor.OrderID = si.OrderID
join Application.People ap on si.PackedByPersonID = ap.PersonID
join Sales.Customers sc on sor.CustomerID = sc.CustomerID
join Application.Cities ac on sc.DeliveryCityID = ac.CityID

where sor.OrderID in
(
	select top 3 with ties sol.OrderID from Sales.OrderLines sol
	order by sol.UnitPrice desc
)
group by sc.DeliveryCityID, ac.CityName, si.PackedByPersonID, ap.FullName

;with cteData (OrderID, DeliveryCityID, CityName, PackedByPersonID, PackedByPerson)
as
(
	select 
	sor.OrderID as OrderID,
	sc.DeliveryCityID as DeliveryCityID,
	ac.CityName as CityName,
	si.PackedByPersonID as PackedByPersonID, 
	ap.FullName as PackedByPerson
	from Sales.Orders sor
	join Sales.Invoices si on sor.OrderID = si.OrderID
	join Application.People ap on si.PackedByPersonID = ap.PersonID
	join Sales.Customers sc on sor.CustomerID = sc.CustomerID
	join Application.Cities ac on sc.DeliveryCityID = ac.CityID
),
cteOrders (OrderID)
as
(
	select top 3 with ties sol.OrderID from Sales.OrderLines sol
	order by sol.UnitPrice desc
)
select 
DeliveryCityID, CityName, PackedByPersonID, PackedByPerson
from cteData d
join  cteOrders o on o.OrderID = d.OrderID

-- ---------------------------------------------------------------------------
-- Опциональное задание
-- ---------------------------------------------------------------------------
-- Можно двигаться как в сторону улучшения читабельности запроса, 
-- так и в сторону упрощения плана\ускорения. 
-- Сравнить производительность запросов можно через SET STATISTICS IO, TIME ON. 
-- Если знакомы с планами запросов, то используйте их (тогда к решению также приложите планы). 
-- Напишите ваши рассуждения по поводу оптимизации. 

-- 5. Объясните, что делает и оптимизируйте запрос

SELECT 
	Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	(SELECT People.FullName
		FROM Application.People
		WHERE People.PersonID = Invoices.SalespersonPersonID
	) AS SalesPersonName,
	SalesTotals.TotalSumm AS TotalSummByInvoice, 
	(SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
		FROM Sales.OrderLines
		WHERE OrderLines.OrderId = (SELECT Orders.OrderId 
			FROM Sales.Orders
			WHERE Orders.PickingCompletedWhen IS NOT NULL	
				AND Orders.OrderId = Invoices.OrderId)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices 
	JOIN
	(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	FROM Sales.InvoiceLines
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
		ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC

-- --

-- запрос выводит данные инвойсов суммой больше 27000

;with cteSalesPersons (PersonID, SalesPersonName)
as
(
	SELECT ap.PersonID as PersonID, ap.FullName as SalesPersonName
	FROM Application.People ap
),
cteTotalSummPickingCompletedWhen (OrderId, TotalSum)
as
(
	SELECT 
	so.OrderId as OrderId,
	SUM(so.PickedQuantity*so.UnitPrice) as TotalSum
		FROM Sales.OrderLines so
	join Sales.Orders o
	on o.OrderId = so.OrderId and o.PickingCompletedWhen is not null
		group by so.OrderId
),
cteSalesTotals (InvoiceId, TotalSumm)
as
(
	select InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	from Sales.InvoiceLines 
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000
)
select si.InvoiceID,
si.InvoiceDate,
csp.SalesPersonName AS SalesPersonName,
st.TotalSumm as TotalSumm,
cp.TotalSum AS TotalSummForPickedItems
from Sales.Invoices si
join cteSalesTotals st
on si.InvoiceID = st.InvoiceId
left join cteSalesPersons csp
on csp.PersonID = si.SalespersonPersonID
left join cteTotalSummPickingCompletedWhen cp
on cp.OrderId = si.OrderID
order by TotalSumm desc
