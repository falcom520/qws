$(function () {
	var getCurrentDay = function() {
        var date = new Date();
        var seperator1 = "-";
        var year = date.getFullYear();
        var month = date.getMonth() + 1;
        var strDate = date.getDate();
        if (month >= 1 && month <= 9) {
            month = "0" + month;
        }
        if (strDate >= 0 && strDate <= 9) {
            strDate = "0" + strDate;
        }
        var currentdate = year + seperator1 + month + seperator1 + strDate;
        return currentdate;
    };
    //Date picker
    $('#start-datepicker').datepicker({
      autoclose: true,
	  format: 'yyyy-mm-dd',
	  todayHighlight:true,
    });
	$('#end-datepicker').datepicker({
      autoclose: true,
	  format: 'yyyy-mm-dd',
	  todayHighlight:true,
    });
	$('#start-datepicker').datepicker("setDate", getCurrentDay());
	$('#end-datepicker').datepicker("setDate", getCurrentDay());
	
	
	//load data
	var load_access_log = function(upstream_id = "",start = "",end = ""){
		if(start == "" || start == undefined){
			start = getCurrentDay();
		}
		if(end == "" || end == undefined){
			end = getCurrentDay();
		}
		$.ajax({
			type  : "GET",
			url   : "/api/stat/get_list",
			data  : {"upstream_id":upstream_id,"stime":start,"etime":end},
			success:function(data){
				if(data.errCode == 0 && data.data.length > 0){
					$("#tips").remove();
					$("#tab-menu ~ tr").remove();
					$.each(data.data,function(k,v){
						var row_class = "";
						if(v.status >= 400 && v.status < 500){
							row_class = "bg-red";
						}else if(v.status >= 500){
							row_class = "bg-yellow";
						}
						var content = "<tr class=\""+row_class+"\">";
						content += "<td>"+(upstream_list[v.upstream_id] ? upstream_list[v.upstream_id] : "unknown")+"</td>";
						content += "<td>"+v.backend+"</td>";
						content += "<td>"+v.uri+"</td>";
						content += "<td>"+v.status+"</td>";
						content += "<td>"+v.request_num+"</td>";
						content += "</tr>";
						$("tbody").append(content);
					});
					
				}else{
					var no_data = "<tr id=\"tips\" style=\"text-align:center;\"><td colspan=\"13\">no data</td></tr>";
					$("#tab-menu ~ tr").remove();
					$("tbody").append(no_data);
				}
			},
		});
	};
	load_access_log();
	
	$("#search-btn").click(function(){
		var upstream_id = $("#upstream_id").val();
		var stime = $("#start-datepicker").val();
		var etime = $("#end-datepicker").val();
		load_access_log(upstream_id,stime,etime);
	});
});