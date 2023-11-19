/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, GROUP BY, HAVING".

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
1. Посчитать среднюю цену товара, общую сумму продажи по месяцам.
Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Средняя цена за месяц по всем товарам
* Общая сумма продаж за месяц

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select 
year(si.InvoiceDate) as SaleYear 
, month(si.InvoiceDate) as MonthNumber
, avg(sil.Quantity * sil.UnitPrice) as AvgMonthPrice
, sum(sil.Quantity * sil.UnitPrice) as SumMonthPrice
from Sales.InvoiceLines sil
join Sales.Invoices si on sil.InvoiceID = si.InvoiceID
group by year(si.InvoiceDate), month(si.InvoiceDate)
order by SaleYear asc, MonthNumber asc

/*
2. Отобразить все месяцы, где общая сумма продаж превысила 4 600 000

Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Общая сумма продаж

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select 
year(si.InvoiceDate) as SaleYear 
, month(si.InvoiceDate) as MonthNumber
, sum(sil.Quantity * sil.UnitPrice) as SumMonthPrice
from Sales.InvoiceLines sil
join Sales.Invoices si on sil.InvoiceID = si.InvoiceID
group by year(si.InvoiceDate), month(si.InvoiceDate)
having sum(sil.Quantity * sil.UnitPrice) > 4600000
order by SaleYear asc, MonthNumber asc

/*
3. Вывести сумму продаж, дату первой продажи
и количество проданного по месяцам, по товарам,
продажи которых менее 50 ед в месяц.
Группировка должна быть по году,  месяцу, товару.

Вывести:
* Год продажи
* Месяц продажи
* Наименование товара
* Сумма продаж
* Дата первой продажи
* Количество проданного

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select 
year(si.InvoiceDate) as SaleYear 
, month(si.InvoiceDate) as MonthNumber
, sil.StockItemID
, ws.StockItemName as ProductName
, sum(sil.Quantity * sil.UnitPrice) as SumMonthPrice
, min(si.InvoiceDate) as MinInvoiceDate
, sum(sil.Quantity) as QuantityNumber
from Sales.InvoiceLines sil
join Sales.Invoices si on sil.InvoiceID = si.InvoiceID
join Warehouse.StockItems ws on sil.StockItemID = ws.StockItemID
group by year(si.InvoiceDate), month(si.InvoiceDate), sil.StockItemID, ws.StockItemName
having sum(sil.Quantity) < 50
order by SaleYear asc, MonthNumber asc

-- ---------------------------------------------------------------------------
-- Опционально
-- ---------------------------------------------------------------------------
/*
Написать запросы 2-3 так, чтобы если в каком-то месяце не было продаж,
то этот месяц также отображался бы в результатах, но там были нули.
*/

select 
year(si.InvoiceDate) as SaleYear 
, month(si.InvoiceDate) as MonthNumber
, case
	when sum(sil.Quantity * sil.UnitPrice) > 4600000 then sum(sil.Quantity * sil.UnitPrice)
	else 0
  end as SumMonthPrice
from Sales.InvoiceLines sil
join Sales.Invoices si on sil.InvoiceID = si.InvoiceID
group by year(si.InvoiceDate), month(si.InvoiceDate)
order by SaleYear asc, MonthNumber asc

select 
year(si.InvoiceDate) as SaleYear 
, month(si.InvoiceDate) as MonthNumber
, sil.StockItemID
, ws.StockItemName as ProductName
, case 
	when sum(sil.Quantity) < 50 then sum(sil.Quantity)
	else 0
  end as SumMonthPrice
, min(si.InvoiceDate) as MinInvoiceDate
, sum(sil.Quantity) as QuantityNumber
from Sales.InvoiceLines sil
join Sales.Invoices si on sil.InvoiceID = si.InvoiceID
join Warehouse.StockItems ws on sil.StockItemID = ws.StockItemID
group by year(si.InvoiceDate), month(si.InvoiceDate), sil.StockItemID, ws.StockItemName
order by SaleYear asc, MonthNumber asc

