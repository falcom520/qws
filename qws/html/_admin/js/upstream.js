$(function(){

    load_upstream();
    function load_upstream(){
      $.post("/api/upstream",{},function(data){
          if(data.errCode == 0 && data.data.length > 0){
          $("#tips").remove();
          $("#tab-menu ~ tr").remove();
          $.each(data.data,function(k,v){
              var content = "<tr>";
              content += "<td>"+(k+1)+"</td>";
              content += "<td>"+v.upstream_id+"</td>";
              content += "<td>"+(v.name ? v.name : "")+"</td>";
              content += "<td>"+v.host+"</td>";
              content += "<td>"+v.scheme+"</td>";
              content += "<td>"+v.lb+"</td>";
              content += "<td>"+v.connect_timeout+"</td>";
              content += "<td>"+v.send_timeout+"</td>";
              content += "<td>"+v.read_timeout+"</td>";
              if(v.is_forbidden == 0){
                content += "<td><span class=\"badge bg-green\">ok</span></td>";
              }else{
                content += "<td><span class=\"badge bg-red\">forbidden</span></td>";
              }
              content += "<td><a href=\"/_admin/upstream/server?upstream_id="+v.upstream_id+"\" class=\"fa fa-server\"></a></td>";
              content += "<td><a href=\"/_admin/upstream/router?upstream_id="+v.upstream_id+"\" class=\"fa fa-crosshairs\"></a></td>";
              content += "<td><div class=\"btn-group\"><button type=\"button\" class=\"btn btn-info\">Action</button><button type=\"button\" class=\"btn btn-info dropdown-toggle\" data-toggle=\"dropdown\" aria-expanded=\"false\"><span class=\"caret\"></span><span class=\"sr-only\">Toggle Dropdown</span></button><ul class=\"dropdown-menu\" role=\"menu\"><li><a href=\"#editModal\" data-toggle=\"modal\" data-upstreamid=\""+v.upstream_id+"\">Edit</a></li><li><a href=\"#delModal\" data-toggle=\"modal\" data-upstreamid=\""+v.upstream_id+"\">Delete</a></li><li><a href=\"/_admin/upstream/server?upstream_id="+v.upstream_id+"\" data-toggle=\"modal\" \">Add Backend</a></li><li><a href=\"/_admin/upstream/router?upstream_id="+v.upstream_id+"\" data-toggle=\"modal\" \">Add Router</a></li></ul></div></td>";
              content += "</tr>";
              $("tbody").append(content);
              });
          }else{
			var no_data = "<tr id=\"tips\" style=\"text-align:center;\"><td colspan=\"13\" class=\"box-title\">no data</td></tr>";
			$("#tab-menu ~ tr").remove();
			$("tbody").append(no_data);
		  }
      });
    }
    $('#editModal').on('show.bs.modal',function(event){
        var upstream_id = $(event.relatedTarget).data('upstreamid');
        $("#edit-tips-err").find("label").html("");
        $.post("/api/upstream/get",{upstream_id:upstream_id},function(data){
            if(data.errCode == 0){
              $("#editform").find("input[name=upstream_id]").val(data.data.upstream_id);
              $("#editform").find("input[name=name]").val(data.data.name);
              $("#editform").find("input[name=host]").val(data.data.host);
              $("#editform").find("input[name=connect_timeout]").val(data.data.connect_timeout);
              $("#editform").find("input[name=send_timeout]").val(data.data.send_timeout);
              $("#editform").find("input[name=read_timeout]").val(data.data.read_timeout);
              $("#editform").find("select[name=lb]").find("option[value="+data.data.lb+"]").attr("selected",true);
              $("#editform").find("select[name=scheme]").find("option[value="+data.data.scheme+"]").attr("selected",true);
			  if(data.data.scheme == "https"){
				  $("#editform").find("#ssl_pem").show();
			  }else{
				  $("#editform").find("#ssl_pem").hide();
			  }
              $("#editform").find("input[name=status][value='"+data.data.is_forbidden+"']").attr("checked",true);
            }else{
              var o = $("#edit-tips-err");
              o.find("label").html("upstream info is not exists.");
              o.addClass("has-warning");
            }
        });
		$("#editModal").find("[name=scheme]").on("change",function(){
			if($(this).val() == "https"){
				$("#editform").find("#ssl_pem").show();
			}else{
				$("#editform").find("#ssl_pem").hide();
			}
		});
    });
    
    $("#editsubmit").click(function(){
      var upstream_id = $("#editform").find("input[name=upstream_id]").val();
      var name = $("#editform").find("input[name=name]").val();
      var host = $("#editform").find("input[name=host]").val();
      var connect_timeout = $("#editform").find("input[name=connect_timeout]").val();
      var send_timeout = $("#editform").find("input[name=send_timeout]").val();
      var read_timeout = $("#editform").find("input[name=read_timeout]").val();
      var lb = $("#editform").find("select[name=lb] option:selected").val();
      var scheme = $("#editform").find("select[name=scheme] option:selected").val();
      var is_forbidden = $("#editform").find("input[name=status]:checked").val();

      var err = 0;
      var o = $("#edit-tips-err");
      if(upstream_id == ""){
        o.find("label").html("please select upstream.");
        o.addClass("has-warning");
        err = 1;
      }
      if(host == ""){
        $("#editform").find("input[name=host]").parent().addClass("has-error");
        err = 1;
      }
      if(err > 0){
        return false;
      }
      o.find("label").html("");
      o.removeClass("has-warning");			
      $.post("/api/upstream/edit",{upstream_id:upstream_id,name:name,host:host,scheme:scheme,connect_timeout:connect_timeout,send_timeout:send_timeout,read_timeout:read_timeout,lb:lb,is_forbidden:is_forbidden},function(data){
          if(data.errCode == 0){
				var pem = $("#editform").find("input[name=ssl_pem]")[0].files[0];
				var crt = $("#editform").find("input[name=ssl_crt]")[0].files[0];
				if(scheme == "https" && (pem != undefined || crt != undefined)){
					var formData = new FormData();
					if(pem != undefined){
						formData.append(host,pem);
					}
					if(crt != undefined){
						formData.append(host,crt);
					}
					$.ajax({
						url : "/api/upload",
						type : "POST",
						data : formData,
						processData : false,
						contentType : false,
						beforeSend : function(){},
						success : function(data){
							is_finish = true;
						},
					});
				}
			  load_upstream();
			  $('.modal').map(function() {
				$(this).modal('hide');
			  });
          }else{
              var o = $("#edit-tips-err");
              o.find("label").html(data.errMsg);
              o.addClass("has-warning");   
          }
      });
    });


    $('#addModal').on('show.bs.modal',function(event){
        $("#add-tips-err").find("label").html("");
		$("#addModal").find("[name=scheme]").on("change",function(){
			if($(this).val() == "https"){
				$("#addform").find("#ssl_pem").show();
			}else{
				$("#addform").find("#ssl_pem").hide();
			}
		});
    });
    $("#refresh").click(function(){
      load_upstream();    
    });
    $("#addsubmit").click(function(){
      var name = $("#addform").find("input[name=name]").val();
      var host = $("#addform").find("input[name=host]").val();
      var scheme = $("#addform").find("select[name=scheme] option:selected").val();
      var lb = $("#addform").find("select[name=lb] option:selected").val();
      var connect_timeout = $("#addform").find("input[name=connect_timeout]").val();
      var send_timeout = $("#addform").find("input[name=send_timeout]").val();
      var read_timeout = $("#addform").find("input[name=read_timeout]").val();
      var is_forbidden = $("#addform").find("input[name=status]:checked").val();
     
      if(host == ""){
        $("#addform").find("input[name=host]").parent().addClass("has-error");
        return false;
      }
      $.post("/api/upstream/add",{name:name,host:host,scheme:scheme,lb:lb,connect_timeout:connect_timeout,send_timeout:send_timeout,read_timeout:read_timeout,is_forbidden:is_forbidden},function(data){
        var o = $("#add-tips-err");
        o.find("label").html("");
        o.removeClass("has-warning");
        if(data.errCode == 0){
			var pem = $("#editform").find("input[name=ssl_pem]")[0].files[0];
			var crt = $("#editform").find("input[name=ssl_crt]")[0].files[0];
			if(scheme == "https" && (pem != undefined || crt != undefined)){
				var formData = new FormData();
				if(pem != undefined){
					formData.append(host,pem);
				}
				if(crt != undefined){
					formData.append(host,crt);
				}
				$.ajax({
					url : "/api/upload",
					type : "POST",
					data : formData,
					processData : false,
					contentType : false,
					beforeSend : function(){},
					success : function(data){
						is_finish = true;
					},
				});
			}
            load_upstream();
            $('.modal').map(function() {
              $(this).modal('hide');
            });
        }else{
            var o = $("#add-tips-err");
            o.find("label").html(data.errMsg);
            o.addClass("has-warning");
        }
      });
        
    });

    $('#delModal').on('show.bs.modal',function(event){
        var upstream_id = $(event.relatedTarget).data('upstreamid');
        $("#delsubmit").attr("data-upstreamid",upstream_id);
    });
    $("#delsubmit").click(function(){
      var upstream_id = $(this).attr("data-upstreamid");
      $("#delModel").find("modal-body").html("do you really remove this upstream?");
      $.post("/api/upstream/del",{upstream_id:upstream_id},function(data){
        if(data.errCode == 0) {
            load_upstream();
            $('.modal').map(function() {
              $(this).modal('hide');
            });
        }else{
          $("#delModel").find(".modal-body").html(data.errMsg);
        }   
      });
    });

});
