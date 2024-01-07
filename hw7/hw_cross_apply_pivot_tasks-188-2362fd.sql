/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "05 - Операторы CROSS APPLY, PIVOT, UNPIVOT".

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
1. Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.

Клиентов взять с ID 2-6, это все подразделение Tailspin Toys.
Имя клиента нужно поменять так чтобы осталось только уточнение.
Например, исходное значение "Tailspin Toys (Gasport, NY)" - вы выводите только "Gasport, NY".
Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+-------------+--------------+------------
InvoiceMonth | Peeples Valley, AZ | Medicine Lodge, KS | Gasport, NY | Sylvanite, MT | Jessie, ND
-------------+--------------------+--------------------+-------------+--------------+------------
01.01.2013   |      3             |        1           |      4      |      2        |     2
01.02.2013   |      7             |        3           |      4      |      2        |     1
-------------+--------------------+--------------------+-------------+--------------+------------
*/

select 
InvoiceMonth,
isnull([Sylvanite, MT], 0) as [Sylvanite, MT],
isnull([Peeples Valley, AZ], 0) as [Peeples Valley, AZ],
isnull([Medicine Lodge, KS], 0) as [Medicine Lodge, KS],
isnull([Gasport, NY], 0) as [Gasport, NY],
isnull([Jessie, ND], 0) as [Jessie, ND]
from
(
	select 
	case i.CustomerID
		when 2 then 'Sylvanite, MT'
		when 3 then 'Peeples Valley, AZ'
		when 4 then 'Medicine Lodge, KS'
		when 5 then 'Gasport, NY'
		when 6 then 'Jessie, ND'
		else ''
	end as CustomerName,
	InvoiceMonth = FORMAT(DATEFROMPARTS(YEAR(i.InvoiceDate),MONTH(i.InvoiceDate),1), 'dd.MM.yyyy'),
	TotalSum = sum(ol.Quantity) 
	from Sales.Invoices i
	join Sales.OrderLines ol on i.OrderID = ol.OrderID
	join Sales.Customers c on i.CustomerID = c.CustomerID
	where i.CustomerID >= 2 and i.CustomerID <= 6
	group by i.CustomerID, c.CustomerName, DATEFROMPARTS(YEAR(i.InvoiceDate),MONTH(i.InvoiceDate),1)
) as Data
pivot (sum(TotalSum) for CustomerName
	in (
	[Sylvanite, MT],
	[Peeples Valley, AZ],
	[Medicine Lodge, KS],
	[Gasport, NY],
	[Jessie, ND]
	))
	AS pvt
	order by InvoiceMonth

/*
2. Для всех клиентов с именем, в котором есть "Tailspin Toys"
вывести все адреса, которые есть в таблице, в одной колонке.

Пример результата:
----------------------------+--------------------
CustomerName                | AddressLine
----------------------------+--------------------
Tailspin Toys (Head Office) | Shop 38
Tailspin Toys (Head Office) | 1877 Mittal Road
Tailspin Toys (Head Office) | PO Box 8975
Tailspin Toys (Head Office) | Ribeiroville
----------------------------+--------------------
*/

select *
from (
	select
	CustomerName,
	DeliveryAddressLine1,
	DeliveryAddressLine2,
	PostalAddressLine1,
	PostalAddressLine2
	from Sales.Customers
	) as customers
	unpivot (CustomerAddress for Name in (
	DeliveryAddressLine1,
	DeliveryAddressLine2,
	PostalAddressLine1,
	PostalAddressLine2))
	as unpvt;

/*
3. В таблице стран (Application.Countries) есть поля с цифровым кодом страны и с буквенным.
Сделайте выборку ИД страны, названия и ее кода так, 
чтобы в поле с кодом был либо цифровой либо буквенный код.

Пример результата:
--------------------------------
CountryId | CountryName | Code
----------+-------------+-------
1         | Afghanistan | AFG
1         | Afghanistan | 4
3         | Albania     | ALB
3         | Albania     | 8
----------+-------------+-------
*/

select *
from (
	select 
	CountryID,
	CountryName,
	IsoAlpha3Code,
	cast(IsoNumericCode as nvarchar(3)) as IsoNumericCodeStr
	from Application.Countries
	) as countries
	unpivot (CountriesCode for Name in (
	IsoAlpha3Code,
	IsoNumericCodeStr
	)) as unpvt;

/*
4. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

select c.CustomerID, 
c.CustomerName,
o2.StockItemID,
o2.UnitPrice,
o2.InvoiceDate
FROM Sales.Customers c
CROSS APPLY (SELECT TOP 2 
				StockItemID = ol.StockItemID,
				UnitPrice = ol.UnitPrice,
				InvoiceDate = i.InvoiceDate
                FROM Sales.OrderLines ol
				join Sales.Orders o 
				on o.OrderID = ol.OrderID
				join Sales.Invoices i 
				on i.OrderID = o.OrderID 
                WHERE o.CustomerID = c.CustomerID
                ORDER BY ol.UnitPrice DESC) AS o2
ORDER BY C.CustomerName;
