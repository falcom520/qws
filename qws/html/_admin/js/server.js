$(function(){

    var upstream_id = $(".box-body").attr("data-upstream-id");
    load_servers();
    function load_servers(){
      $.post("/api/servers",{upstream_id:upstream_id},function(data){
          $("#upstream_host").html(data.data.upstream.host);
          if(data.errCode == 0 && data.data.servers.length > 0){
          $("#tips").remove();
          $("#tab-menu ~ tr").remove();
          $.each(data.data.servers,function(k,v){
              var content = "<tr>";
              content += "<td>"+(k+1)+"</td>";
              if(k == 0){
              content += "<td rowspan=\""+data.data.servers.length+"\" style=\"vertical-align:middle;text-align:center;display: table-cell;\"><h5>"+(data.data.upstream.name ? data.data.upstream.name : "")+"<br />"+data.data.upstream.host+"</h5></td>";
              }
              content += "<td>"+v.server_id+"</td>";
              content += "<td>"+v.server+"</td>";
              content += "<td>"+v.port+"</td>";
              if(v.status == 0){
                content += "<td><span class=\"badge bg-green\">ok</span></td>";
              }else{
                content += "<td><span class=\"badge bg-red\">fail</span></td>";
              }
              if(v.is_forbidden == 0){
                content += "<td><span class=\"badge bg-green\">ok</span></td>";
              }else{
                content += "<td><span class=\"badge bg-red\">forbidden</span></td>";
              }
              content += "<td><div class=\"btn-group\"><button type=\"button\" class=\"btn btn-info\">Action</button><button type=\"button\" class=\"btn btn-info dropdown-toggle\" data-toggle=\"dropdown\" aria-expanded=\"false\"><span class=\"caret\"></span><span class=\"sr-only\">Toggle Dropdown</span></button><ul class=\"dropdown-menu\" role=\"menu\"><li><a href=\"#editModal\" data-toggle=\"modal\" data-server-id=\""+v.server_id+"\">Edit</a></li><li><a href=\"#delModal\" data-toggle=\"modal\" data-server-id=\""+v.server_id+"\">Delete</a></li></ul></div></td>";
              content += "</tr>";
              $("tbody").append(content);
              });
          }else{
			 var no_data = "<tr id=\"tips\" style=\"text-align:center;\"><td colspan=\"10\" class=\"box-title\">no data</td></tr>";
			$("#tab-menu ~ tr").remove();
			$("tbody").append(no_data);
		  }
      });
    }
    $('#editModal').on('show.bs.modal',function(event){
        var server_id = $(event.relatedTarget).data('server-id');
        $("#edit-tips-err").find("label").html("");
        $.post("/api/servers/get",{server_id:server_id},function(data){
            if(data.errCode == 0){
              $("#editform").find("input[name=server_id]").val(data.data.server_id);
              $("#editform").find("input[name=server]").val(data.data.server);
              $("#editform").find("input[name=port]").val(data.data.port);
              var option = $("#editform").find("select[name=status]").find("option");
              for(var i = 0;i<option.length;i++){
                if(option[i].value == data.data.status){
                  option[i].selected = true;
                }else{
                  option[i].selected = false;
                }
              }
              var radio = $("#editform").find("input[name=is_forbidden]");
              for(var i=0;i<radio.length;i++){
                if(radio[i].value == data.data.is_forbidden){
                  radio[i].checked = true;
                }else{
                  radio[i].checked = false;
                }
              }
            }else{
              var o = $("#edit-tips-err");
              o.find("label").html("upstream info is not exists.");
              o.addClass("has-warning");
            }
        });
    });
    
    $("#editsubmit").click(function(){
      var server_id = $("#editform").find("input[name=server_id]").val();
      var server = $("#editform").find("input[name=server]").val();
      var port = $("#editform").find("input[name=port]").val();
      var is_forbidden = $("#editform").find("input[name=is_forbidden]:checked").val();

      var err = 0;
      var o = $("#edit-tips-err");
      if(server_id == ""){
        o.find("label").html("please select server_id.");
        o.addClass("has-warning");
        err = 1;
      }
      if(server == ""){
        $("#editform").find("input[name=server]").parent().addClass("has-error");
        err = 1;
      }
      if(err > 0){
        return false;
      }
      o.find("label").html("");
      o.removeClass("has-warning");
      $.post("/api/servers/edit",{server_id:server_id,server:server,port:port,is_forbidden:is_forbidden},function(data){
          if(data.errCode == 0){
              load_servers();
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
    });
    $("#refresh").click(function(){
      load_servers();    
    });
    $("#addsubmit").click(function(){
      var server = $("#addform").find("input[name=server]").val();
      var port = $("#addform").find("input[name=port]").val();
      var is_forbidden = $("#addform").find("input[name=status]:checked").val();
     
      if(server == ""){
        $("#addform").find("input[name=server]").parent().addClass("has-error");
        return false;
      }
      $.post("/api/servers/add",{server:server,port:port,is_forbidden:is_forbidden,upstream_id:upstream_id},function(data){
        var o = $("#add-tips-err");
        o.find("label").html("");
        o.removeClass("has-warning");
        if(data.errCode == 0){
            load_servers();
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
        var server_id = $(event.relatedTarget).data('server-id');
        $("#delsubmit").attr("data-server-id",server_id);
        $(this).find("div .modal-body").html("do you really remove this server?");
        $(this).find("div .modal-body").removeClass("text-red");
    });
    $("#delsubmit").click(function(){
      var server_id = $(this).attr("data-server-id");
      $.post("/api/servers/del",{server_id:server_id},function(data){
        if(data.errCode == 0) {
            load_servers();
            $('.modal').map(function() {
              $(this).modal('hide');
            });
        }else{
          $("#delModal").find("div .modal-body").html(data.errMsg);
          $("#delModal").find("div .modal-body").addClass("text-red");
        }   
      });
    });

});
