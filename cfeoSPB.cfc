<!--- 
	ColdFusion stored procedure broker - dynamically builds cfstoredproc calls - works with mssql

	@param 	spName  	name of the stored procedure
	@param  dataStruct 	optional argument containing a structure of parameters
	@param  resultSets	set the number of resultSets being returned from the stored procedure

	@author	Ryan Smith (rsmith@eomedia.com)
	@version 1, July 2013

	@licensed under the MIT and GPL licenses:
 	http://www.opensource.org/licenses/mit-license.php
 	http://www.gnu.org/license


	Usage:
	
	manually initialize component:
	
		<cfset cfeoSPB = createObject("component","path_to_cfc.cfeoSPB").Init("MyDatasourceName") />

	build/pass the data structure if required:
	
		<cfset dataStruct = StructNew() />
		<cfset dataStruct.id = 1 />
		<cfset dataStruct.colVarChar = "New Text" />
		
		<cfset results = cfeoSPB.callSP("spName",dataStruct, 1) />
	
--->

<cfcomponent>
	
		
	<cffunction name="Init" access="Public" returntype="any" output="false" hint="builds the cfeoSPB instance">
		
		<cfset variables.Instance["spList"] = {} />		
		<cfreturn this />
		
	</cffunction>
	
	

	<cffunction name="getSPs" access="public" output="false" returntype="struct">
		<cfreturn variables.Instance.spList />
	</cffunction>
	
	<cffunction name="getSPparams" output="false" returntype="array" hint="Returns an array which contains info about a SPs parameters.">
	
		<cfargument name="SPName" type="string" required="Yes" />
					
			
			<!--- set the array to hold all sp params --->
			<cfset spArray = arrayNew(1)>
			
			
			<!--- Retrieve info about the SP's parameters from the database --->
			<cfstoredproc datasource="#getDatasource().getDatasourceName()#" procedure="sp_sproc_columns">
				<cfprocresult name="paramList">
				<cfprocparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.spName#">
			</cfstoredproc>
			
			<!---<cfdump var="#paramList#" label="storedProc">--->
			
			<!--- if we find a valid sp --->
			<cfif paramList.recordCount>
				<!--- loop over params --->
				<cfloop query="paramList">
		
					<!--- set the structure to hold the params for this loop --->
					<cfscript>
						st = structNew();
						st.colName = column_name;
						st.colLength = char_octet_length;
						st.colType = column_type;
						st.ordinalPosition = ordinal_position;
		
						switch(column_type){
							case "0":
							st.CFParamType = "param_type_unknown";
							break;
							case "1":
							st.CFParamType = "IN";
							break;
							case "2":
							st.CFParamType = "OUT";
							break;
							case "3":
							st.CFParamType = "result_col";
							break;
							case "4":
							st.CFParamType = "param_output";
							break;
							case "5":
							st.CFParamType = "return_value";
							break;
						}
			
						st.SQLType = type_name;
						
						// based on the type set the CF_SQL_TYPE
						switch(type_name) {
							case "bit":
							st.CFType = "boolean";
							st.CFSQLType = "CF_SQL_BIT";
							break;
							case "tinyint": case "smallint": case "int": case "bigint": case "decimal": case "numeric": case "float": case "real": case "smallmoney": case ",money":
							st.CFType = "numeric";
						switch(type_name){
							case "tinyint":
							st.CFSQLType = "CF_SQL_TINYINT";
							break;
							case "smallint":
							st.CFSQLType = "CF_SQL_SMALLINT";
							break;
							case "int": case "bigint":
							st.CFSQLType = "CF_SQL_INTEGER";
							break;
							case "float":
							st.CFSQLType = "CF_SQL_FLOAT";
							break;
							case "real":
							st.CFSQLType = "CF_SQL_REAL";
							break;
							case "numeric":
							st.CFSQLType = "CF_SQL_NUMERIC";
							break;
							case "smallmoney": case "money": case "decimal":
							st.CFSQLType = "CF_SQL_DECIMAL";
							break;
						}
					// if decimal or numeric reset and include the precision and scale
					if (listFindNoCase("decimal,numeric", type_name)){
						st.SQLType = type_name & "(" & Precision & "," & Scale & ")";
						st.CFSQLScale = scale;
					} else if (listFindNoCase("smallmoney,money", type_name)){
						// money we set a maximum scale of 4
						st.CFSQLScale = 4;
					}
					break;
					case "char": case "nchar": case "varchar": case "nvarchar": case "text": case "ntext": case "sql-varinat":
					st.CFType = "string";
						switch(type_name){
							case "char": case "nchar":
							st.CFSQLType = "CF_SQL_CHAR";
							break;
							case "varchar": case "nvarchar": case "sql": case "sql_variant":
							st.CFSQLType = "CF_SQL_VARCHAR";
							break;
							case "text": case "ntext":
							st.CFSQLType = "CF_SQL_LONGVARCHAR";
							break;
						}
					// if char, nchar, varchar, nvarchar reset with precision
					if (listFindNoCase("char,nchar,varchar,nvarchar", type_name)){
						st.SQLType = type_name & "(" & precision & ")";
					}
					break;
					case "binary": case "image": case "varbinary":
					st.CFType = "binary";
						switch(type_name){
							case "binary":
							st.CFSQLType = "CF_SQL_BINARY";
							break;
							case "image":
							st.CFSQLType = "CF_SQL_LONGVARBINARY";
							break;
							case "varbinary":
							st.CFSQLType = "CF_SQL_VARBINARY";
							break;
						}
					// if binary or varbinary reset with precsion
					if (listFindNoCase("binary,varbinary", type_name)){
						st.SQLType = type_name & "(" & precision & ")";
					}
					break;
					case "smalldatetime": case "datetime":
					st.CFType = "datetime";
					st.CFSQLType = "CF_SQL_TIMESTAMP";
					break;
					case "uniqueidentifier":
					st.CFType = "guid";
					st.CFSQLType = "CF_SQL_IDSTAMP";
					break;
				}
				// end switch
				
				// if a param is found we add it to the array
				if (structKeyExists(st,"CFType")){
					arrayAppend(spArray, st);
				}
			</cfscript>

		</cfloop>
		
		<cfreturn spArray>
		
	</cfif>
	</cffunction>
	
	
	<cffunction name="callSP" access="public" output="false" returntype="Struct" hint="Calls a stored procedure automatically passing parameters to it.">
	
		<cfargument name="spName" type="string" required="Yes"/>
		<cfargument name="dataStruct" type="struct" required="No" default="#StructNew()#" />
		<cfargument name="resultSets" type="string" required="No" default="1"/>

		
		<!--- create a shortcut reference for the dataStructure --->
		<cfset data = Arguments.dataStruct>
		
		<!--- check if storedProc exists in instance, if not add it --->
		<cfif !structKeyExists(variables.instance.spList,Arguments.spName)>
			<cfset structInsert(variables.instance.spList,Arguments.spName,getSPparams(Arguments.spName,variables.Instance["datasource"].getDatasourceName()),true)>
		</cfif>
		
		<!--- set params locally for use in stored proc --->
		<cfset spParams = variables.instance.spList[Arguments.spName]>
		
		<!--- set holder for OUT params - list will be appended with OUT variable names --->
		<cfset spOutParam = "">

				
		<!--- try for errors --->
		<cftry>
		
		<!--- build and call the storedProc --->
		<cfstoredproc datasource="#variables.instance["datasource"].getDatasourceName()#" procedure="#Arguments.spName#" returncode="true" result="spResult">
			
			<!--- process resultSets --->
			<cfloop index="i" from="1" to="#Arguments.resultSets#">
				<cfprocresult name="rs#i#" resultset="#i#">
			</cfloop>
			
			<!--- loop over params and build the calls --->
			<cfloop from="1" to="#arraylen(spParams)#" step="1" index="paramIndex">
			
			<!--- only process IN & OUT param types --->
			<cfif spParams[paramIndex].CFParamType EQ "IN" OR spParams[paramIndex].CFParamType EQ "OUT">
			
				<cfscript>
					// set the fieldName from colName
					var fieldName = replace(spParams[paramIndex].colName,"@","");
					
					// default use of NULL
					var isNull = "false";
					
					// check that param exits in scope OR if it's boolean
					if (structKeyExists(data,fieldName) OR spParams[paramIndex].CFType EQ "boolean"){
						// format the values
						switch(spParams[paramIndex].CFType) {
							// apply val() to all numeric values
							case "numeric":
							local.value = val(data[fieldName]);
							break;
							// no formatting is required
							case "string": case "binary": case "guid":
							local.value = data[fieldName];
							break;
							// if bit field, apply the Val() function, if not we are assuming that its value should be passed as zero (0) - e.g. checkbox processing
							case "boolean":
							if (structKeyExists(data,fieldName)){
								local.value = val(data[fieldName]);
							} else {
								local.value = 0;
							}
							break;
							//  apply CreateODBCDateTime() function to all datetime parameters if they exist in the data struct and are valid dates, otherwise pass the value as NULL
							case "datetime":
							if (len(data[fieldName]) AND isDate(data[fieldName])){
								local.value = createODBCDateTime(data[fieldName]);
							} else {
								local.value = "NULL";
							}
							break;
						}
						// end switch
					} else {
						// no data supplied for param so we NULL it
						var isNull = "true";
						local.value = "NULL";
					}
					// end structKeyExists
				</cfscript>

				
				<cfif StructKeyExists(spParams[paramIndex],"CFSQLScale")>
					<cfprocparam type="#spParams[paramIndex].CFParamType#" cfsqltype="#spParams[paramIndex].CFSQLType#" value="#local.value#" scale="#spParams[paramIndex].CFSQLScale#" null="#isNull#">
				<cfelseif spParams[paramIndex].colType EQ "2">
									
					<cfset spOutParam = listAppend(spOutParam,fieldName)> <!--- add param to OUT list to be used in RESULTS --->

					<!--- compenstate for INOUT - CFParamType only allows IN or OUT --->
					<cfif isNull EQ "true">
						<!--- if there is not a valid value provided for OUT param, include a variable to hold the OUTPUT value --->
						<cfprocparam type="#spParams[paramIndex].CFParamType#" cfsqltype="#spParams[paramIndex].CFSQLType#" variable="#fieldName#">
					<cfelse>
						<!--- if there is a value provided for OUT param, change procparam to INOUT and include value --->
						<cfprocparam type="INOUT" cfsqltype="#spParams[paramIndex].CFSQLType#" value="#local.value#" variable="#fieldName#">
					</cfif>
					
				<cfelse>
					<cfprocparam type="#spParams[paramIndex].CFParamType#" cfsqltype="#spParams[paramIndex].CFSQLType#" value="#local.value#" null="#isNull#">
				</cfif>
				
				
			</cfif>
			<!--- end: if paramtype is IN or OUT ---> 
				
			</cfloop>
		</cfstoredproc>
		
		<!--- catch errors --->		
		<cfcatch type="any">
			
			<!--- DEFAULT ERROR HANDLING --->
			<cfset spResult.statusCode = "-1">
			<cfset spResult.statusMessage = "Unknown error">
			
			<!--- exception --->
			<cfif isDefined("cfcatch.message")><cfset spResult.statusMessage = cfcatch.message></cfif>
			
			<!---- database --->
			<cfif isDefined('cfcatch.nativeErrorcode')>
				<cfset spResult.statusCode = cfcatch.nativeErrorCode>
				<cfif isDefined("cfcatch.message")>
					<cfset spResult.statusMessage = cfcatch.nativeErrorcode & " : " & cfcatch.message> <!--- change to cfcatch.queryError for more specfic --->
				</cfif>
			</cfif>
			
			<!--- send an email notification --->
			<cfsavecontent variable="content">
				<cfdump var='#arguments#' label='arguments'><cfdump var='#cfcatch#' label='cfcatch'>
			</cfsavecontent>
			<!--- example of integration with email gateway <cfset getEmail().sendEmail(from="",type="error",subject="error[model.gateways.cfeoSPB].callSP",content=content) /> --->
						
		</cfcatch>
		
		</cftry>
		
			
		<!--- get the error message --->
		<cfscript>
			// create a results structu
			var results = {};
			
			// return the statusCode and statusMessage  (e.g. 0 | success )
			results.statusCode = spResult.statusCode;
			results.executionTime = spResult.executionTime;
			
			// if there are no errors reset the statusMessage to the matching dB content
			if (results.statusCode EQ 0 OR results.statusCode >= 50000){
				var siteError = getSite().getSiteError(results.statusCode);
				var statusMessage = siteError.errorContent;
			} else {
				// statusCode would be set in cftry above
				var statusMessage = spResult.statusMessage; 
			}
			results.statusMessage = statusMessage;
			
			// process resultSets & add to RESULTS structure
			for ( 
				row = 1; 
				row LTE Arguments.resultSets; 
				row = (row + 1) 
				) {
				// try/catch enables dynamic SP calls where number of result sets varies based on input
				try {
					results["RS#row#"] = evaluate("rs" & row);
					} catch(any e){ }		
				}
				
			// process spOutParams (type=OUT) for inclusion
			for (
				i =  1;
				i LTE listlen(spOutParam);
				i = ( i + 1)
				) {
				fieldName = listGetAt(spOutParam, i);
				results["#UCASE(fieldName)#"] = evaluate(fieldName);
				}
		</cfscript>	
		

		<!--- log errors that are generated --->
		<cfif results.statusCode NEQ 0>
			<cflog file="storedProc" type="Information" text="cfeoSPB #Arguments.spName# ERROR: #results.statusCode# - #results.statusMessage#">
		</cfif>
		
		<!--- return results to caller --->
		<cfreturn results>	
		
	</cffunction>
	
	
</cfcomponent>