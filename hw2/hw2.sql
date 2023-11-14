-- 1. Все товары, в названии которых есть "urgent" или название начинается с "Animal".

select * from Warehouse.StockItems 
where StockItemName like '%urgent%' 
or StockItemName like 'Animal%'

-- 2. Поставщиков (Suppliers), у которых не было сделано ни одного заказа (PurchaseOrders).

select suppliers.SupplierID, suppliers.SupplierName from Purchasing.Suppliers suppliers
where suppliers.SupplierID in
(select suppliers.SupplierID 
from Purchasing.Suppliers suppliers
except
select orders.SupplierID from Purchasing.PurchaseOrders orders)

-- 3. Заказы (Orders) с ценой товара (UnitPrice) более 100$ либо количеством единиц (Quantity) товара более 20 штуки
--    присутствующей датой комплектации всего заказа (PickingCompletedWhen).

select * from Sales.Orders o
where o.OrderID in 
(select distinct ol.OrderID from Sales.OrderLines ol 
where (ol.UnitPrice > 100
or ol.Quantity > 20)
and ol.PickingCompletedWhen is not null)

-- 4. Заказы поставщикам (Purchasing.Suppliers), которые должны быть исполнены (ExpectedDeliveryDate) в январе 2013 года с
-- доставкой "Air Freight" или "Refrigerated Air Freight" (DeliveryMethodName) и которые исполнены (IsOrderFinalized).

select po.PurchaseOrderID, po.SupplierID, ps.SupplierName from Purchasing.PurchaseOrders po
join  Application.DeliveryMethods dm
on po.DeliveryMethodID = dm.DeliveryMethodID and (dm.DeliveryMethodName = 'Air Freight' or dm.DeliveryMethodName = 'Refrigerated Air Freight')
join Purchasing.Suppliers ps on ps.SupplierID = po.SupplierID
where year(po.ExpectedDeliveryDate) = 2013
and MONTH(po.ExpectedDeliveryDate) = 1
and po.IsOrderFinalized = 1

-- 5. Десять последних продаж (по дате продажи) с именем клиента и именем сотрудника, который оформил заказ
--    (SalespersonPerson). Сделать без подзапросов.

select top 10 
so.OrderID, 
so.OrderDate, 
sc.CustomerName, 
so.SalespersonPersonID, 
ap.FullName as Salesperson 
from Sales.Orders so
join Sales.Customers sc on so.CustomerID = sc.CustomerID
join Application.People ap on ap.PersonID = so.SalespersonPersonID
order by so.OrderDate desc, so.OrderID desc

-- 6. Все ид и имена клиентов и их контактные телефоны, которые покупали товар "Chocolate frogs 250g".

select ap.PersonID, ap.FullName, ap.PhoneNumber, ap.EmailAddress from Application.People ap
where ap.PersonID in
	(select 
	distinct sc.PrimaryContactPersonID as PersonID
	from Sales.OrderLines sol
	join Warehouse.StockItems ws on sol.StockItemID = ws.StockItemID
	join Sales.Orders so on sol.OrderID = so.OrderID 
	join Sales.Customers sc on so.CustomerID = sc.CustomerID
	where ws.StockItemName = 'Chocolate frogs 250g'
	union
	select 
	distinct sc.AlternateContactPersonID as PersonID
	from Sales.OrderLines sol
	join Warehouse.StockItems ws on sol.StockItemID = ws.StockItemID
	join Sales.Orders so on sol.OrderID = so.OrderID 
	join Sales.Customers sc on so.CustomerID = sc.CustomerID
	where ws.StockItemName = 'Chocolate frogs 250g')
