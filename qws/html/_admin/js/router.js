$.fn.stringify = function() {
  return JSON.stringify(this);
}
$(function(){

    var upstream_id = $(".box-body").attr("data-upstream-id");
    load_routers();
    function load_routers(){
      $.post("/api/router",{upstream_id:upstream_id},function(data){
          if(data.errCode == 0 && data.data.routers.length > 0){
          $("#tips").remove();
          $("#tab-menu ~ tr").remove();
          $("#upstream_host").text(data.data.upstream.name+"("+data.data.upstream.host+")");
          $.each(data.data.routers,function(k,v){
              var content = "<tr>";
              content += "<td>"+(k+1)+"</td>";
              content += "<td>"+v.router_id+"</td>";
              var server = "";
              if(v.server_id){
                for(i=0;i<v.server_id.length;i++){
                  server += "Server:"+v.server_id[i]+"<br />";
                }
              }
              content += "<td>"+server+"</td>";
              var rule = "";
              if(v.rule){
                if(v.rule.CLIENTIP){
                    rule += "ClientIP:";
                  for(i = 0;i<v.rule.CLIENTIP.length;i++){
                    if(i == v.rule.CLIENTIP.length - 1){
                    rule += v.rule.CLIENTIP[i];
                    }else{
                    rule += v.rule.CLIENTIP[i]+",";
                    
                    }
                  }
                  rule += "<br />";
                }
				if(v.rule.ABTest){
					rule += "ABTest:"+v.rule.ABTest+"<br />";
				}
                if(v.rule.HEADERS){
                  for(i=0;i<v.rule.HEADERS.length;i++){
                  $.each(v.rule.HEADERS[i],function(k1,v1){
                      rule += "head "+k1+":"+v1+"<br />";
                      });
                  }
                }
                if(v.rule.URI){
                  for(i=0;i<v.rule.URI.length;i++){
                    $.each(v.rule.URI[i],function(k1,v1){
                        rule += "Query "+k1+":"+v1+"<br />";
                        });
                  }
                }
              }
              content += "<td>"+rule+"</td>";
              content += "<td>"+v.uri+"</td>";
              content += "<td>"+v.new_uri+"</td>";
              if(v.is_forbidden == 0){
                content += "<td><span class=\"badge bg-green\">ok</span></td>";
              }else{
                content += "<td><span class=\"badge bg-red\">forbidden</span></td>";
              }
              content += "<td><div class=\"btn-group\"><button type=\"button\" class=\"btn btn-info\">Action</button><button type=\"button\" class=\"btn btn-info dropdown-toggle\" data-toggle=\"dropdown\" aria-expanded=\"false\"><span class=\"caret\"></span><span class=\"sr-only\">Toggle Dropdown</span></button><ul class=\"dropdown-menu\" role=\"menu\"><li><a href=\"#editModal\" data-toggle=\"modal\" data-router-id=\""+v.router_id+"\">Edit</a></li><li><a href=\"#delModal\" data-toggle=\"modal\" data-router-id=\""+v.router_id+"\">Delete</a></li></ul></div></td>";
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
        var router_id = $(event.relatedTarget).data('router-id');
        $("#edit-tips-err").find("label").html("");
        $.post("/api/router/get",{router_id:router_id},function(data){
            if(data.errCode == 0){
              $("#editform").find("input[name=router_id]").val(data.data.router_id);
              var server = "";
              if(data.data.server_list){
                if(data.data.server_list.length == data.data.server_id.length){
                  server = "<div class=\"checkbox\"><label><input type=\"checkbox\" name=\"server_id\" value=\"0\" checked=\"true\">All</label></div>";
                }else{
                  server = "<div class=\"checkbox\"><label><input type=\"checkbox\" name=\"server_id\" value=\"0\">All</label></div>";
                }
                $.each(data.data.server_list,function(k,v){
                    var checked = "";
                    if(data.data.server_id){
                      $.each(data.data.server_id,function(k1,v1){
                          if(v1 == v.server_id && checked == ""){
                            checked = "checked=\"true\"";
                          }
                      });
                    }
                    server += "<div class=\"checkbox\"><label><input type=\"checkbox\" name=\"server_id\" value=\""+v.server_id+"\" "+checked+">"+v.server+":"+v.port+"</label></div>";
                });
              }
              $("#edit-server-option").html(server);
              var rule = "";
			  var label = "Rule";
			  var style_x = "visibility:hidden";
              if(data.data.rule){
				$("#rule-option").html("");
                $.each(data.data.rule,function(k,v){
                  if(k =="CLIENTIP"){
					var clientip = "";
                    $.each(data.data.rule.CLIENTIP,function(k1,v1){
						if(clientip != ""){
							clientip += ","+v1;
						}else{
							clientip = v1;
						}
					});

					var content = "<label for=\"scheme\" class=\"col-sm-2 control-label\">"+label+"</label><div class=\"col-lg-8 clspaddingr\" name='rulerows' ><div><div class=\"input-group\"><div class=\"input-group-btn\"> <select class=\"btn btn-default\"><option value=\"CLIENTIP\" selected=\"true\">ClientIP</option><option value=\"ABTest\">ABTest</option><option value=\"HEAD\">head</option><option value=\"URI\">Query</option></select></div><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"clientip\" placeholder=\"param\" value=\""+clientip+"\"><div class=\"rows\" style=\"display:none;\"><div class=\"col-lg-4 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"field\" placeholder=\"param\"></div><div class=\"col-lg-8 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"value\" placeholder=\"value\"></div></div></div></div></div><div class=\"col-lg-1 clspaddingr\" style=\""+(label != "" ? style_x : '')+"\"><i class=\"fa fa-fw fa-close hclsbtn\"></i></div>";
					$("#rule-option").append(content);
					if(label != ""){
						label = "";
					}
                  }else if(k == "HEADERS"){
					$.each(data.data.rule.HEADERS,function(k1,v1){
						$.each(v1,function(k2,v2){
							var content = "<label for=\"scheme\" class=\"col-sm-2 control-label\">"+label+"</label><div class=\"col-lg-8 clspaddingr\" name='rulerows' ><div><div class=\"input-group\"><div class=\"input-group-btn\"> <select class=\"btn btn-default\"><option value=\"CLIENTIP\" >ClientIP</option><option value=\"ABTest\">ABTest</option><option value=\"HEAD\" selected=\"true\">head</option><option value=\"URI\">Query</option></select></div><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"clientip\" placeholder=\"param\" value=\"\" style=\"display:none;\"><div class=\"rows\"><div class=\"col-lg-4 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"field\" placeholder=\"param\" value=\""+k2+"\"></div><div class=\"col-lg-8 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"value\" placeholder=\"value\" value=\""+v2+"\"></div></div></div></div></div><div class=\"col-lg-1 clspaddingr\" style=\""+(label != "" ? style_x : '')+"\"><i class=\"fa fa-fw fa-close hclsbtn\"></i></div>";
							$("#rule-option").append(content);
							if(label != ""){
								label = "";
							}
						});
					});
				  }else if(k == "URI"){
					$.each(data.data.rule.URI,function(k1,v1){
						$.each(v1,function(k2,v2){
							var content = "<label for=\"scheme\" class=\"col-sm-2 control-label\">"+label+"</label><div class=\"col-lg-8 clspaddingr\" name='rulerows' ><div><div class=\"input-group\"><div class=\"input-group-btn\"> <select class=\"btn btn-default\"><option value=\"CLIENTIP\" >ClientIP</option><option value=\"ABTest\">ABTest</option><option value=\"HEAD\">head</option><option value=\"URI\" selected=\"true\">Query</option></select></div><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"clientip\" placeholder=\"param\" value=\"\" style=\"display:none;\"><div class=\"rows\"><div class=\"col-lg-4 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"field\" placeholder=\"param\" value=\""+k2+"\"></div><div class=\"col-lg-8 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"value\" placeholder=\"value\" value=\""+v2+"\"></div></div></div></div></div><div class=\"col-lg-1 clspaddingr\" style=\""+(label != "" ? style_x : '')+"\"><i class=\"fa fa-fw fa-close hclsbtn\"></i></div>";
							$("#rule-option").append(content);
							if(label != ""){
								label = "";
							}
						});
					});
				  }else if(k == "ABTest"){
					var abtest = data.data.rule.ABTest;
					var content = "<label for=\"scheme\" class=\"col-sm-2 control-label\">"+label+"</label><div class=\"col-lg-8 clspaddingr\" name='rulerows' ><div><div class=\"input-group\"><div class=\"input-group-btn\"> <select class=\"btn btn-default\"><option value=\"CLIENTIP\" >ClientIP</option><option value=\"ABTest\" selected=\"true\">ABTest</option><option value=\"HEAD\">head</option><option value=\"URI\">Query</option></select></div><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"clientip\" placeholder=\"param\" value=\""+abtest+"\"><div class=\"rows\" style=\"display:none;\"><div class=\"col-lg-4 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"field\" placeholder=\"param\"></div><div class=\"col-lg-8 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"value\" placeholder=\"value\"></div></div></div></div></div><div class=\"col-lg-1 clspaddingr\" style=\""+(label != "" ? style_x : '')+"\"><i class=\"fa fa-fw fa-close hclsbtn\"></i></div>";
					$("#rule-option").append(content);
					if(label != ""){
						label = "";
					}
				  }
                });
              }

			for(var i=0;i<$("[name=rulerows]").length;i++){
				$("[name=rulerows]").eq(i).click(function(){
					if($(this).find("select option:selected").val() == 'CLIENTIP'){
						$(this).find(".form-control").show().next().hide();
						$(this).find("input[name=clientip]").attr("placeholder","192.168.1.200,210.12.20.100");
					}else if($(this).find("select option:selected").val() == "ABTest"){
						$(this).find(".form-control").show().next().hide();
						$(this).find("input[name=clientip]").attr("placeholder",0.5);
					}else if($(this).find("select option:selected").val() == 'HEAD'){
						$(this).find(".form-control").hide().next().show().find("input").show();
					}else if($(this).find("select option:selected").val() == 'URI'){
						$(this).find(".form-control").hide().next().show().find("input").show();
					}
				});
			}
			for(var j=0;j<$(".col-lg-1").length;j++){
				$(".col-lg-1").eq(j).click(function(){
					
					$(this).prev().prev().remove();
					$(this).prev().remove();
					$(this).remove();
				})
			}

			  
			  
              $("#editform").find("input[name=uri]").val(data.data.uri);
              $("#editform").find("input[name=new_uri]").val(data.data.new_uri);
              $("#editform").find("input[name=is_forbidden][value='"+data.data.is_forbidden+"']").attr("checked",true);
            }else{
              var o = $("#edit-tips-err");
              o.find("label").html("upstream info is not exists.");
              o.addClass("has-warning");
            }
			
			$($("#editform").find("input[name=server_id]")).eq(0).click(function(){
				if($(this).context.checked){
					$.each($("#editform").find("input[name=server_id]"),function(i,n){
						if(i > 0){
							$(n).prop("checked",true)
						}
					});
				}
			});
			
			$.each($("#editform").find("input[name=server_id]"),function(i,n){
				$(n).click(function(){
					if($(this).val() != 0 && $(this).attr("checked")){
						$("#editform").find("input[name=server_id]").eq(0).prop("checked",false);
					}
				});
			});
			
        });

	  
    });
    

    $("#edit-add-rule").click(function(){
        var content = "<label for=\"scheme\" class=\"col-sm-2 control-label\">&nbsp;&nbsp;</label><div class=\"col-lg-8 clspaddingr\" name='rulerows'><div><div class=\"input-group\"><div class=\"input-group-btn\"> <select class=\"btn btn-default\"><option value=\"CLIENTIP\">ClientIP</option><option value=\"ABTest\">ABTest</option><option value=\"HEAD\">head</option><option value=\"URI\">Query</option></select></div><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"clientip\" placeholder=\"param\"><div class=\"rows\" style=\"display:none;\"><div class=\"col-lg-4 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"field\" placeholder=\"param\"></div><div class=\"col-lg-8 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"value\" placeholder=\"value\"></div></div></div></div></div><div class=\"col-lg-1 clspaddingr\"><i class=\"fa fa-fw fa-close hclsbtn\"></i></div>";
        $("#rule-option").append(content);
		for(var i=0;i<$("[name=rulerows]").length;i++){
			$("[name=rulerows]").eq(i).click(function(){
				if($(this).find("select option:selected").val() == 'CLIENTIP'){
					$(this).find(".form-control").show().next().hide();
					$(this).find("input[name=clientip]").attr("placeholder","192.168.1.200,210.12.20.100");
				}else if($(this).find("select option:selected").val() == "ABTest"){
					$(this).find(".form-control").show().next().hide();
					$(this).find("input[name=clientip]").attr("placeholder",0.5);
				}else if($(this).find("select option:selected").val() == 'HEAD'){
					$(this).find(".form-control").hide().next().show().find("input").show();
				}else if($(this).find("select option:selected").val() == 'URI'){
					$(this).find(".form-control").hide().next().show().find("input").show();
				}
			});
		}
		for(var j=0;j<$(".col-lg-1").length;j++){
			$(".col-lg-1").eq(j).click(function(){
				
				$(this).prev().prev().remove();
				$(this).prev().remove();
				$(this).remove();
			})
		}
    });
	
    $("#add-add-rule").click(function(){
        var content = "<label for=\"scheme\" class=\"col-sm-2 control-label\">&nbsp;&nbsp;</label><div class=\"col-lg-8 clspaddingr\" name='rulerows'><div><div class=\"input-group\"><div class=\"input-group-btn\"> <select class=\"btn btn-default\"><option value=\"CLIENTIP\">ClientIP</option><option value=\"ABTest\">ABTest</option><option value=\"HEAD\">head</option><option value=\"URI\">Query</option></select></div><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"clientip\" placeholder=\"param\"><div class=\"rows\" style=\"display:none;\"><div class=\"col-lg-4 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"field\" placeholder=\"param\"></div><div class=\"col-lg-8 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"value\" placeholder=\"value\"></div></div></div></div></div><div class=\"col-lg-1 clspaddingr\"><i class=\"fa fa-fw fa-close hclsbtn\"></i></div>";
        $("#rule-option-add").append(content);
		for(var i=0;i<$("[name=rulerows]").length;i++){
			$("[name=rulerows]").eq(i).click(function(){
				if($(this).find("select option:selected").val() == 'CLIENTIP'){
					$(this).find(".form-control").show().next().hide();
					$(this).find("input[name=clientip]").attr("placeholder","192.168.1.200,210.12.20.100");
				}else if($(this).find("select option:selected").val() == "ABTest"){
					$(this).find(".form-control").show().next().hide();
					$(this).find("input[name=clientip]").attr("placeholder",0.5);
				}else if($(this).find("select option:selected").val() == 'HEAD'){
					$(this).find(".form-control").hide().next().show().find("input").show();
				}else if($(this).find("select option:selected").val() == 'URI'){
					$(this).find(".form-control").hide().next().show().find("input").show();
				}
			});
		}
		for(var j=0;j<$(".col-lg-1").length;j++){
			$(".col-lg-1").eq(j).click(function(){
				
				$(this).prev().prev().remove();
				$(this).prev().remove();
				$(this).remove();
			})
		}
    });
	

    $("#editsubmit").click(function(){
      var router_id = $("#editform").find("input[name=router_id]").val();
      var uri = $("#editform").find("input[name=uri]").val();
      var new_uri = $("#editform").find("input[name=new_uri]").val();
      var server_id = new Array();
	  $.each($("#editform").find("input[name=server_id]:checked"),function(i,v){
		  server_id[i] = $(v).val();
	  });
	  var server_ids = JSON.stringify(server_id);
	  var rule_field = new Array();
	  var ii = 0;
      $.each($("#editform").find("select option:selected"),function(i,v){
		  var type = $(v).val();
		  if(type == "CLIENTIP"){
			  var clientip = $($("#editform").find("input[name=clientip]")[i]).val();
			  if(clientip != ""){
				  rule_field[ii] = {'t':'CLIENTIP','v':clientip};
				  ii++;
			  }
		  }else if(type == "ABTest"){
			  var abtest = $($("#editform").find("input[name=clientip]")[i]).val();
			  if(abtest != ""){
				  rule_field[ii] = {'t':'ABTest','v':abtest};
				  ii++;
			  }
		  }else{
			  var field = $($("#editform").find("input[name=field]")[i]).val();
			  var val = $($("#editform").find("input[name=value]")[i]).val();
			  if(field != "" && val != ""){
				  rule_field[ii] = {'t':type,'k':field,'v':val};
				  ii++;
			  }
		  }  
	  });
      var is_forbidden = $("#editform").find("input[name=is_forbidden]:checked").val();
	  var rule = JSON.stringify(rule_field);
	  
      $.post("/api/router/edit",{router_id:router_id,uri:uri,new_uri:new_uri,server_id:server_ids,rule:rule,is_forbidden:is_forbidden},function(data){
          if(data.errCode == 0){
              load_routers();
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
		var upstream_id = $(event.relatedTarget).data('upstream-id');
		$("#addform").find("input[name=upstream_id]").val(upstream_id);
        $("#add-tips-err").find("label").html("");
		$("#rule-option-add").html("");
		$.post('/api/router/get_server',{upstream_id:upstream_id},function(data){
			if(data.errCode == 0){
				var server = "";
				if(data.data){
					$.each(data.data,function(k,v){
						server += "<div class=\"checkbox\"><label><input type=\"checkbox\" name=\"server_id\" value=\""+v.server_id+"\" >"+v.server+"</label></div>";
					});
				}
				$("#add-server-option").html(server);
			}
		});
		var content = "<label for=\"scheme\" class=\"col-sm-2 control-label\">Rule</label><div class=\"col-lg-8 clspaddingr\" name='rulerows' ><div><div class=\"input-group\"><div class=\"input-group-btn\"> <select class=\"btn btn-default\"><option value=\"CLIENTIP\" selected=\"true\">ClientIP</option><option value=\"ABTest\">ABTest</option><option value=\"HEAD\">head</option><option value=\"URI\">Query</option></select></div><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"clientip\" placeholder=\"param\" value=\"\"><div class=\"rows\" style=\"display:none;\"><div class=\"col-lg-4 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"field\" placeholder=\"param\"></div><div class=\"col-lg-8 clspaddingr zeromargin\"><input type=\"text\" class=\"form-control\" aria-label=\"...\" name=\"value\" placeholder=\"value\"></div></div></div></div></div><div class=\"col-lg-1 clspaddingr\" style=\"visibility:hidden\"><i class=\"fa fa-fw fa-close hclsbtn\"></i></div>";
		$("#rule-option-add").html(content);
		
		for(var i=0;i<$("[name=rulerows]").length;i++){
			$("[name=rulerows]").eq(i).click(function(){
				if($(this).find("select option:selected").val() == 'CLIENTIP'){
					$(this).find(".form-control").show().next().hide();
					$(this).find("input[name=clientip]").attr("placeholder","192.168.1.200,210.12.20.100");
				}else if($(this).find("select option:selected").val() == "ABTest"){
					$(this).find(".form-control").show().next().hide();
					$(this).find("input[name=clientip]").attr("placeholder",0.5);
				}else if($(this).find("select option:selected").val() == 'HEAD'){
					$(this).find(".form-control").hide().next().show().find("input").show();
				}else if($(this).find("select option:selected").val() == 'URI'){
					$(this).find(".form-control").hide().next().show().find("input").show();
				}
			});
		}
		for(var j=0;j<$(".col-lg-1").length;j++){
			$(".col-lg-1").eq(j).click(function(){
				
				$(this).prev().prev().remove();
				$(this).prev().remove();
				$(this).remove();
			})
		}
    });
	
    $("#refresh").click(function(){
      load_routers();    
    });
    $("#addsubmit").click(function(){
	  var upstream_id = $("#addform").find("input[name=upstream_id]").val();
      var uri = $("#addform").find("input[name=uri]").val();
      var new_uri = $("#addform").find("input[name=new_uri]").val();
      var server_id = new Array();
	  $.each($("#addform").find("input[name=server_id]:checked"),function(i,v){
		  server_id[i] = $(v).val();
	  });
	  var server_ids = JSON.stringify(server_id);
	  var rule_field = new Array();
	  var ii = 0;
      $.each($("#addform").find("select option:selected"),function(i,v){
		  var type = $(v).val();
		  if(type == "CLIENTIP"){
			  var clientip = $($("#addform").find("input[name=clientip]")[i]).val();
			  if(clientip != ""){
				  rule_field[ii] = {'t':'CLIENTIP','v':clientip};
				  ii++;
			  }
		  }else if(type == "ABTest"){
			  var abtest = $($("#addform").find("input[name=clientip]")[i]).val();
			  if(abtest != ""){
				  rule_field[ii] = {'t':'ABTest','v':abtest};
				  ii++;
			  }
		  }else{
			  var field = $($("#addform").find("input[name=field]")[i]).val();
			  var val = $($("#addform").find("input[name=value]")[i]).val();
			  if(field != "" && val != ""){
				  rule_field[ii] = {'t':type,'k':field,'v':val};
				  ii++;
			  }
		  }  
	  });
      var is_forbidden = $("#addform").find("input[name=is_forbidden]:checked").val();
	  var rule = JSON.stringify(rule_field);
	  
      $.post("/api/router/add",{upstream_id:upstream_id,uri:uri,new_uri:new_uri,server_id:server_ids,rule:rule,is_forbidden:is_forbidden},function(data){
          if(data.errCode == 0){
              load_routers();
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

    $('#delModal').on('show.bs.modal',function(event){
        var router_id = $(event.relatedTarget).data('router-id');
        $("#delsubmit").attr("data-router-id",router_id);
    });
    $("#delsubmit").click(function(){
      var router_id = $(this).attr("data-router-id");
      $("#delModel").find("modal-body").html("do you really remove this router?");
      $.post("/api/router/del",{router_id:router_id},function(data){
        if(data.errCode == 0) {
            load_routers();
            $('.modal').map(function() {
              $(this).modal('hide');
            });
        }else{
          $("#delModel").find("modal-body").html(errMsg);
        }   
      });
    });

});
