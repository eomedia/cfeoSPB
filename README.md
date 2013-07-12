###cfeoSPB
============

ColdFusion stored procedure broker - dynamically builds cfstoredproc calls - works with mssql

cfeoSPB sits between you calling CF page and the stored procedure within MSSQL and automates the process of building your cfstoredproc calls.  In addition to the major savings in writing a ton of code, it also helps prevent code breaks when a SP is updated with non-required varaibles.  

cfeoSPB dynamically builds the SP by comparing the stored procedure varaibles against the data passed in the dataStruct and when no match is found it passes the parameter as a NULL variable.  This means that if you update a SP with an optional flag value you do not need to change any cfstoredproc tags in your code because you didn't write any to start with.



```
##Dual licensed under the MIT and GPL licenses:
* http://www.opensource.org/licenses/mit-license.php
* http://www.gnu.org/license
```

```
## cfeoSPB parameters
@param 	spName  	name of the stored procedure
@param  dataStruct 	optional argument containing a structure of parameters
@param  resultSets	set the number of resultSets being returned from the stored procedure
```

```
#Quick use case example

	current method:

	<cfstoredproc datasource="#datasource#" procedure="spName">

		<cfprocparam type="in" value="#Arguments.one#" cfsqltype="CF_SQL_VARCHAR">
		<cfprocparam type="in" value="#Arguments.two#" cfsqltype="CF_SQL_VARCHAR">
		<cfprocparam type="in" value="#Arguments.three#" cfsqltype="CF_SQL_VARCHAR" null="true">
		<cfprocparam type="in" value="#Arguments.four#" cfsqltype="CF_SQL_VARCHAR" null="true">
		
		<cfprocresult name="rs1" resultset="1">
		<cfprocresult name="rs2" resultset="2">
		
	</cfstoredproc>
		
		<!---create a return array--->
		<cfloop index="i" from="1" to="2">
			<cfset resultsAry[i] = evaluate("rs" & i)>
		</cfloop>
		
		<!---return the array to the calling page--->
		<cfreturn resultsAry>


	
	cfeoSPB method:

	<cfset cfeoSPB = createObject("component","path_to_cfc.cfeoSPB").Init("MyDatasourceName") />

	<cfset dataStruct = StructNew() />
	<cfset dataStruct.one = "one" />
	<cfset dataStruct.two = "two" />
		
	<cfset results = cfeoSPB.callSP("spName",dataStruct, 2) />

	<cfreturn results >

```

This is a simple example but imagine a stored procedure with thirty or more parameters and you can see the savings in code, as well as the benefical ability to simply ignore optional parameters that are not necessary.
