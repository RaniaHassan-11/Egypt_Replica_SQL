
/*- ---------------------------------------------------- support arabic Lanaguage---------------------------------  */
-- Attempt to alter the database collation with a lock timeout option
ALTER DATABASE [EGYPT] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
ALTER DATABASE [EGYPT] COLLATE Arabic_CI_AI;
GO
ALTER DATABASE [EGYPT] SET MULTI_USER;
GO

/*- -------------------------------------------------------------Trigger------------------------------------------------------------  */

/*- Trigger---------------------------------------------------- prevent inserting a Branch ---------------------------------  */

CREATE OR ALTER TRIGGER Branch_insert
ON Branches
INSTEAD OF INSERT
AS
BEGIN
    PRINT 'Cannot insert a new record into this table.';
END;

/*- Trigger------------------------------------ prevent Update any record in table product_ordered ---------------------------------  */
CREATE OR ALTER TRIGGER Product_order_update
ON [dbo].[Product_Orderd]
INSTEAD OF UPDATE AS
BEGIN
    SELECT 'Updates are not allowed on this table.';
END;

/*- Trigger-------------------------------- Update only in column  TypeOfPayment in table [Orders] ---------------------------------  */

CREATE OR ALTER TRIGGER order_type
ON [dbo].[Orders]
AFTER UPDATE
AS
BEGIN
    DECLARE @type VARCHAR(50),
            @OrderId INT,
            @TourGuide_Snn INT
    SELECT @type = TypeOfPayment FROM inserted
    SELECT @OrderId = Order_ID, @TourGuide_Snn = TourGuide_SSN FROM deleted
    UPDATE Orders 
    SET Order_ID = @OrderId, TourGuide_SSN = @TourGuide_Snn, TypeOfPayment = @type 
    WHERE Order_ID = @OrderId
    SELECT 'TypeOfPayment only Updated'
END

UPDATE [dbo].[Orders]
SET TourGuide_SSN = 1245687,
    TypeOfPayment = 'card'
WHERE Order_ID = 12345;

/*- -------------------------------------------------------------View------------------------------------------------------------  */

/*- View----------------- Wind Function (Dense_ra--------------------- Expensive_Product_in_Each_Category----------------------  */
create or alter view Expensive_Product_in_Each_Category
as 
select * from 
(
	select * , Dense_rank() over (partition by Category_ID order by Product_Name desc) as DN
	from Products 

) as newTable
where DN = 1

select * from Expensive_Product_in_Each_Category
/*- View-------------------------------- show the count of employee in each  Branch ---------------------------------  */

CREATE OR ALTER VIEW Branch_date AS
SELECT b.Branch_Name,COUNT(e.SSN) AS totalemployee
FROM Branches b JOIN Employee e 
ON e.branch_id = b.Branch_ID GROUP BY b.Branch_Name

select * from Branch_date

/*- View-------------------------------- show all product which have price more than 10000 ---------------------------------  */

CREATE OR ALTER VIEW product_price_more_10000 AS
SELECT * FROM Products
where Product_Price > 10000
select * from product_price_more_10000

/*- -------------------------------------------------------------CURSOR------------------------------------------------------------  */


/*- CURSOR---------------------------------------------------- Update Salary for each Employee---------------------------------  */

DECLARE c9 CURSOR FOR
SELECT b.Branch_ID, e.Salary 
FROM Branches b 
JOIN Employee e ON b.Branch_ID = e.branch_id;
DECLARE @branch_id INT, @sal INT;
OPEN c9;
FETCH NEXT FROM c9 INTO @branch_id, @sal;
WHILE @@FETCH_STATUS = 0
BEGIN
	
    UPDATE Employee
    SET Salary = ROUND(Salary * ( @branch_id/10 + 1),2)
    WHERE branch_id = @branch_id;
    FETCH NEXT FROM c9 INTO @branch_id, @sal;
END
CLOSE c9;
DEALLOCATE c9;

/*- -------------------------------------------------------------Procedure------------------------------------------------------------  */


/*- procedure---------------------------------------------------- about_Quantity---------------------------------  */

create  or alter proc about_Quantity @check bit 
as
	if @check=0
		begin 
			SELECT  p.Product_Name, ([Amount])
			FROM Product_Orderd po , Products p
			WHERE po.Product_ID = p.Product_ID
		end
	else
		begin 
			SELECT  p.Product_Name, sum(sp.Available_Quantity) as [Available_Quantity]
			FROM Stock_Has_Product sp , Products p
			WHERE sp.Product_ID = p.Product_ID
			group by p.Product_Name
		end


exec about_Quantity 0

/*- procedure---------------------------------------------------- Add Prpduct---------------------------------  */
create or alter proc addPorder @product_id bigint ,@TOfPayment varchar(50), @tour_ssn int,@amount int as

begin transaction
-- declare variable
declare @total_price float , @branch_id int , @price float , @orderID int = NEXT VALUE FOR Order_counter ;
-- get price for Product
select @price = Product_Price from Products where Product_ID = @product_id 
-- get branch_id take from it Product
select top 1 @branch_id = b.Branch_id
from Branches b, Stock_Has_Product sp
where b.Stock_ID = sp.Stock_ID and sp.Product_ID = @product_id
-- insert data into Orders table
insert into Orders(Order_ID,TypeOfPayment,TourGuide_SSN) values (@orderID,@TOfPayment,@tour_ssn)
-- insert data into Product_Orderd table
insert into Product_Orderd([Product_ID],[order_ID],[Amount],[Product_Price],[Branch_id])
values (@product_id,@orderID,@amount,@price,@branch_id)
-- get all Data about Order after created
exec dbo.getOrderData  @orderID
-- update Quentity after Order after created
exec dbo.updateProductQuentity @product_id , @amount
commit transaction


exec addPorder 1070101010001,'Creidt Card' , 71239390 , 7

/*- procedure---------------------------------------------------- getOrderData---------------------------------  */
create proc getOrderData @orderID int as
select * , dbo.getTotalPrice(@orderID) as [Total Price]
from Product_Orderd where order_ID = @orderID

exec getOrderData  321326
/*- procedure---------------------------------------------------- Product_With_Price_Between---------------------------------  */

create or alter Proc Product_With_Price_Between @P1 float , @P2 float
as 
select * from Products 
where Product_Price Between @P1 and @P2

Product_With_Price_Between 150 , 200.50

/*- procedure---------------------------------------------------- updateProductQuentity---------------------------------  */
create or alter proc updateProductQuentity @productID bigint,@quantity int as
update Stock_Has_Product set Available_Quantity =Available_Quantity-@quantity 
where Product_ID = @productID
select 'Quentity Updated'

exec updateProductQuentity  1070101010001 , 5

/*- procedure---------------------------------------------------- GetMaxSalaries---------------------------------  */

 CREATE OR ALTER PROCEDURE GetMaxSalaries
    @N INT
AS
BEGIN
    SELECT TOP (@N) 
        e.FirstName + ' ' + e.FirstName AS fullname,
        e.Salary
    FROM 
        Employee e
    ORDER BY 
        e.Salary DESC;
END;


EXEC GetMaxSalaries @N = 10;

/*- function---------------------------------------------------- max_tourguide_order---------------------------------  */
CREATE OR ALTER FUNCTION max_tourguide_order()
RETURNS @t TABLE (Tourguide_name NVARCHAR(100), Total_Order INT)
AS
BEGIN
    INSERT INTO @t
    SELECT  top 1 CONCAT(T.FirstName, ' ', T.lastname) as [Full NAme], COUNT(*)
    FROM Tourguide T
    JOIN Orders O ON T.SSN = O.TourGuide_SSN
    GROUP BY T.FirstName, T.lastname
    ORDER BY COUNT(*) DESC

    RETURN
END;

select * from max_tourguide_order()

/*- function---------------------------------------------------- max_product_has_quentity---------------------------------  */

CREATE OR ALTER FUNCTION max_product_has_quentity()
RETURNS VARCHAR(20)
BEGIN
    DECLARE @product_name VARCHAR(20)
    SELECT @product_name = p.Product_Name
    FROM Product_Orderd po
    JOIN Products p ON p.Product_ID = po.Product_id
    WHERE amount = (SELECT MAX(amount) FROM Product_Orderd)
    RETURN @product_name
END;


select dbo.max_quantity()

/*- function---------------------------------------------------- getTotalPrice---------------------------------  */
create function getTotalPrice (@order_ID int) 
returns float
begin
declare @totalPrice float
select @totalPrice = Amount*Product_Price from Product_Orderd 
where order_ID = @order_ID
return @totalPrice
end

select dbo.getTotalPrice (11223) as [Total Price]

/*- -------------------------------------------------------------Index------------------------------------------------------------  */


/*- Index-------------------------------------- create clustered inde on Product Name---------------------------------------------  */

create unique index Product_index
on Products(Product_Name)
/*- Index-------------------------------------- create Unique index on Branches name-----------------------------------------------  */

create Unique index Branch_Name_index on Branches(Branch_Name)

/*- Index-------------------------------------- create nonclustered index on Tourguide Name--------------------------------  */
/* */
create nonclustered index Tourguide_Name_index on Tourguide(FirstName)

/*- SEQUENCE---------------------------------------------------- Order_counter---------------------------------  */
CREATE SEQUENCE Order_counter
START WITH 321322
INCREMENT BY 1;
