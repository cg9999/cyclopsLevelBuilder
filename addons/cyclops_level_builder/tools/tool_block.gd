# MIT License
#
# Copyright (c) 2023 Mark McKay
# https://github.com/blackears/cyclopsLevelBuilder
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

@tool
extends CyclopsTool
class_name ToolBlock

enum DragStyle { NONE, READY, BLOCK_BASE, BLOCK_HEIGHT, MOVE_BLOCK, MOVE_FACE }
var drag_style:DragStyle = DragStyle.NONE
#enum State { READY, DRAG_BASE }
#var dragging:bool = false
var viewport_camera_start:Camera3D
var event_start:InputEventMouseButton

var block_drag_cur:Vector3
var block_drag_p0_local:Vector3
var block_drag_p1_local:Vector3
var block_drag_p2_local:Vector3

var drag_floor_normal:Vector3

var min_drag_distance:float = 4

#Keep a copy of move command here while we are building it
var cmd_move_blocks:CommandMoveBlocks
var cmd_move_face:CommandMoveFace
var move_face_origin:Vector3 #Kep track of the origin when moving a face

func start_block_drag(viewport_camera:Camera3D, event:InputEvent):
	var blocks_root:CyclopsBlocks = self.builder.active_node
	var e:InputEventMouseButton = event
	
	var origin:Vector3 = viewport_camera.project_ray_origin(e.position)
	var dir:Vector3 = viewport_camera.project_ray_normal(e.position)

#					print("origin %s  dir %s" % [origin, dir])

	var result:IntersectResults = blocks_root.intersect_ray_closest(origin, dir)
#					print("result %s" % result)
	
	if result:
#						print("Hit! %s" % result)
		drag_floor_normal = MathUtil.snap_to_best_axis_normal(result.normal)

		var start_pos:Vector3 = result.position
		var w2l = blocks_root.global_transform.inverse()
		var start_pos_local:Vector3 = w2l * start_pos

		var grid_step_size:float = pow(2, blocks_root.grid_size)

		block_drag_p0_local = MathUtil.snap_to_grid(start_pos_local, grid_step_size)
		
		if e.shift_pressed:
			drag_style = DragStyle.MOVE_FACE
			
			cmd_move_face = CommandMoveFace.new()
			cmd_move_face.face_id = result.face_id
			cmd_move_face.tracked_block = result.object
			cmd_move_face.tracked_block_data = result.object.block_data
			cmd_move_face.lock_uvs = builder.lock_uvs
			move_face_origin = result.position
			cmd_move_face.move_dir_normal = result.object.control_mesh.faces[result.face_id].plane.normal
			
		elif result.object.selected:
			drag_style = DragStyle.MOVE_BLOCK
			
			cmd_move_blocks = CommandMoveBlocks.new()
			cmd_move_blocks.lock_uvs = builder.lock_uvs
			for child in blocks_root.get_children():
				if child is CyclopsBlock and child.selected:
					cmd_move_blocks.add_block(child)
		else:
			drag_style = DragStyle.BLOCK_BASE

		
	else:
#						print("Miss")
		drag_floor_normal = Vector3.UP
		
		drag_style = DragStyle.BLOCK_BASE
		var start_pos:Vector3 = origin + builder.block_create_distance * dir
		var w2l = blocks_root.global_transform.inverse()
		var start_pos_local:Vector3 = w2l * start_pos

		#print("start_pos %s" % start_pos)
		#print("start_pos_local %s" % start_pos_local)
		
		var grid_step_size:float = pow(2, blocks_root.grid_size)

		
		#print("start_pos_local %s" % start_pos_local)
		block_drag_p0_local = MathUtil.snap_to_grid(start_pos_local, grid_step_size)
		
		#print("block_drag_start_local %s" % block_drag_start_local)
	#print("set 1 drag_style %s" % drag_style)

func _gui_input(viewport_camera:Camera3D, event:InputEvent)->bool:	
	var blocks_root:CyclopsBlocks = self.builder.active_node
	
	if event is InputEventMouseButton:
		
		var e:InputEventMouseButton = event
		if e.button_index == MOUSE_BUTTON_LEFT:

			if e.is_pressed():
				if drag_style == DragStyle.NONE:
					event_start = event
					viewport_camera_start = viewport_camera
					
					drag_style = DragStyle.READY
				
			else:
				if drag_style == DragStyle.READY:
					
					var origin:Vector3 = viewport_camera.project_ray_origin(e.position)
					var dir:Vector3 = viewport_camera.project_ray_normal(e.position)

					var result:IntersectResults = blocks_root.intersect_ray_closest(origin, dir)
					
					if result:
						if e.ctrl_pressed:
							result.object.selected = !result.object.selected
						else:
							for child in blocks_root.get_children():
								if child is CyclopsBlock:
									var block:CyclopsBlock = child
									block.selected = block == result.object
						pass
					
					drag_style = DragStyle.NONE
					
				elif drag_style == DragStyle.BLOCK_BASE:
					block_drag_p1_local = block_drag_cur
					drag_style = DragStyle.BLOCK_HEIGHT
					
					#print("set 2 drag_style %s" % drag_style)
					
				elif drag_style == DragStyle.BLOCK_HEIGHT:
#					print("Adding block %s %s %s" % [block_drag_p0_local, block_drag_p1_local, block_drag_p2_local])
					block_drag_p2_local = block_drag_cur
					drag_style = DragStyle.NONE

					var global_scene:CyclopsGlobalScene = builder.get_node("/root/CyclopsAutoload")
					global_scene.clear_tool_mesh()

					var bounds:AABB = AABB(block_drag_p0_local, Vector3.ZERO)
					bounds = bounds.expand(block_drag_p1_local)
					bounds = bounds.expand(block_drag_p2_local)
					
#					print("AABB %s" % bounds)
					
					if bounds.has_volume():
						var command:CommandAddBlock2 = CommandAddBlock2.new()
						
						#var block:CyclopsBlock = preload("../controls/cyclops_block.gd").new()
						command.block_name = GeneralUtil.find_unique_name(builder.active_node, "Block_")
						
#						var name_idx:int = 0
#						while true:
#							var name = "Block_%s" % name_idx
#							if !builder.active_node.find_child(name, false):
##								block.name = name
#								command.block_name = name
#								break
#							name_idx += 1

						command.blocks_root_inst_id = blocks_root.get_instance_id()
						command.block_owner = builder.get_editor_interface().get_edited_scene_root()
						command.bounds = bounds

						var undo:EditorUndoRedoManager = builder.get_undo_redo()

						command.add_to_undo_manager(undo)

				elif drag_style == DragStyle.MOVE_BLOCK:

					var undo:EditorUndoRedoManager = builder.get_undo_redo()
					cmd_move_blocks.add_to_undo_manager(undo)
					
					drag_style = DragStyle.NONE			
				
				elif drag_style == DragStyle.MOVE_FACE:

					var undo:EditorUndoRedoManager = builder.get_undo_redo()
					cmd_move_face.add_to_undo_manager(undo)
					
					drag_style = DragStyle.NONE			
				
			return  true
			
	elif event is InputEventMouseMotion:
		var e:InputEventMouseMotion = event

		var origin:Vector3 = viewport_camera.project_ray_origin(e.position)
		var dir:Vector3 = viewport_camera.project_ray_normal(e.position)
		
		var start_pos:Vector3 = origin + builder.block_create_distance * dir
		var w2l = blocks_root.global_transform.inverse()
		var origin_local:Vector3 = w2l * origin
		var dir_local:Vector3 = w2l.basis * dir
	
		var global_scene:CyclopsGlobalScene = builder.get_node("/root/CyclopsAutoload")
		
		#print("drag_style %s" % drag_style)
		
		if drag_style == DragStyle.NONE:
			if e.shift_pressed:
				#block_drag_cur = MathUtil.intersect_plane(origin_local, dir_local, block_drag_p0_local, drag_floor_normal)
				var result:IntersectResults = blocks_root.intersect_ray_closest(origin, dir)
				if result:
					var block:CyclopsBlock = result.object
					var convex_mesh:ConvexMesh = block.control_mesh.calc_mesh()
					var points:PackedVector3Array = convex_mesh.get_face_points(result.face_id)
					#var face = block.control_mesh.faces[result.face_index]
					#var points:PackedVector3Array = block.control_mesh.get_face_points(face)
					
					global_scene.draw_loop(points, true)
					return true
				else:
					global_scene.clear_tool_mesh()
					
			else:
				global_scene.clear_tool_mesh()

				
		elif drag_style == DragStyle.READY:
			var offset:Vector2 = e.position - event_start.position
			if offset.length() > min_drag_distance:
				start_block_drag(viewport_camera_start, event_start)

			return true
				
		elif drag_style == DragStyle.BLOCK_BASE:

			block_drag_cur = MathUtil.intersect_plane(origin_local, dir_local, block_drag_p0_local, drag_floor_normal)
			
			#print("block_drag_cur %s" % block_drag_cur)
			
			var grid_step_size:float = pow(2, blocks_root.grid_size)
			block_drag_cur = MathUtil.snap_to_grid(block_drag_cur, grid_step_size)

			#print("block_drag_cur snapped %s" % block_drag_cur)
			
			#Draw tool
			var p01:Vector3
			var p10:Vector3
			if abs(drag_floor_normal.x) > abs(drag_floor_normal.y) and abs(drag_floor_normal.x) > abs(drag_floor_normal.z):
				p01 = Vector3(block_drag_p0_local.x, block_drag_p0_local.y, block_drag_cur.z)
				p10 = Vector3(block_drag_p0_local.x, block_drag_cur.y, block_drag_p0_local.z)
			elif abs(drag_floor_normal.y) > abs(drag_floor_normal.z):
				p01 = Vector3(block_drag_p0_local.x, block_drag_p0_local.y, block_drag_cur.z)
				p10 = Vector3(block_drag_cur.x, block_drag_p0_local.y, block_drag_p0_local.z)
			else:
				p01 = Vector3(block_drag_p0_local.x, block_drag_cur.y, block_drag_p0_local.z)
				p10 = Vector3(block_drag_cur.x, block_drag_p0_local.y, block_drag_p0_local.z)
			global_scene.draw_loop([block_drag_p0_local, p01, block_drag_cur, p10], true)

			return true

		elif drag_style == DragStyle.BLOCK_HEIGHT:
#			block_drag_cur = MathUtil.intersect_plane(origin_local, dir_local, block_drag_p0_local, Vector3.UP)
			block_drag_cur = MathUtil.closest_point_on_line(origin_local, dir_local, block_drag_p1_local, drag_floor_normal)
			
			var grid_step_size:float = pow(2, blocks_root.grid_size)
			block_drag_cur = MathUtil.snap_to_grid(block_drag_cur, grid_step_size)
			
			global_scene.draw_cube(block_drag_p0_local, block_drag_p1_local, block_drag_cur)

			return true

		elif drag_style == DragStyle.MOVE_BLOCK:
			if e.alt_pressed:
#				block_drag_cur = MathUtil.closest_point_on_line(origin_local, dir_local, block_drag_p0_local, drag_floor_normal)
				block_drag_cur = MathUtil.closest_point_on_line(origin_local, dir_local, block_drag_p0_local, Vector3.UP)
			else:
#				block_drag_cur = MathUtil.intersect_plane(origin_local, dir_local, block_drag_p0_local, drag_floor_normal)
				block_drag_cur = MathUtil.intersect_plane(origin_local, dir_local, block_drag_p0_local, Vector3.UP)
			
			var grid_step_size:float = pow(2, blocks_root.grid_size)
			block_drag_cur = MathUtil.snap_to_grid(block_drag_cur, grid_step_size)
			
			cmd_move_blocks.move_offset = block_drag_cur - block_drag_p0_local
			cmd_move_blocks.do_it()

			return true
			
		elif drag_style == DragStyle.MOVE_FACE:			
			var drag_to:Vector3 = MathUtil.closest_point_on_line(origin_local, dir_local, move_face_origin, cmd_move_face.move_dir_normal)
			#print("move_face_origin %s norm %s" % [move_face_origin, cmd_move_face.move_dir_normal])
			var grid_step_size:float = pow(2, blocks_root.grid_size)
			drag_to = MathUtil.snap_to_grid(drag_to, grid_step_size)
			
			cmd_move_face.move_amount = (drag_to - move_face_origin).dot(cmd_move_face.move_dir_normal)
			
			cmd_move_face.do_it_intermediate()
		
			return true
	
	return super._gui_input(viewport_camera, event)		


