<?
function smarty_block_MTAjaxRatingList($args, $content, &$ctx, &$repeat) {
    $localvars = array('entry', '_entries_counter','entries','current_timestamp','modification_timestamp','_entries_lastn', 'current_timestamp_end', 'DateHeader', 'DateFooter', 'EntryBreak', 'object', 'objects', 'obj_type');
    if (!isset($content)) {
        $ctx->localize($localvars);
        if (count($args) && ($ctx->stash('objects')))
            $ctx->__stash['objects'] = null;
        $counter = 0;
        $lastn = $args['show_n'];
        $obj_type = $args['type'];
        if ($obj_type == 'trackback') { $obj_type = 'ping'; }
        $ctx->stash('obj_type',$obj_type);
        $ctx->stash('_entries_lastn', $lastn);
    } else {
        $lastn = $ctx->stash('_entries_lastn');
        $counter = $ctx->stash('_entries_counter');
    }
    $objects = $ctx->stash('objects');
    if (!isset($objects)) {
        $args['blog_id'] = $ctx->stash('blog_id');

        // ENTRY SELECTION LOGIC
            $_fp = 'ajaxrating_votesummary_';
            $table = 'mt_ajaxrating_votesummary';
            if ($args['hot']) { 
                $_fp = 'ajaxrating_hotobject_';
                $table = 'mt_ajaxrating_hotobject';
            }
            // Choose a field
            $pop_sort_by = $_fp . 'total_score';
            $pop_obj_type = $_fp . 'obj_type';
            if (strtolower($args['sort_by']) == 'votes') { $pop_sort_by = $_fp . 'vote_count'; }
            elseif (strtolower($args['sort_by']) == 'average') { $pop_sort_by = $_fp . 'avg_score'; }

            // Choose Sort Direction
            $pop_direction = 'DESC'; $pop_wall = "$pop_sort_by > 0 AND $pop_obj_type = '$obj_type'";
            if (strtolower($args['sort_order']) == 'ascend') { $pop_direction = 'ASC'; $pop_wall = "$pop_sort_by < 0 AND $pop_obj_type = '$obj_type'"; }
            if ($args['blogs'] != 'all') { $pop_wall .= " AND {$_fp}blog_id = '{$args['blog_id']}'"; }
            
            //
            $objects = array();
            $object_args = array();
            $pop_entries = $ctx->mt->db->get_results("SELECT * FROM $table WHERE $pop_wall ORDER BY $pop_sort_by $pop_direction", ARRAY_A);
            foreach($pop_entries as $pop_entry) {
                $eid = $pop_entry[$_fp . 'obj_id'];
                $object_args['id'] = $eid;
                if ($obj_type == 'entry') {
                    $e = $ctx->mt->db->fetch_entry($eid);
                } else {
                    if ($obj_type == 'ping') {
                        list($e) = $ctx->mt->db->load('tbping',$object_args);
                    } else {
                        list($e) = $ctx->mt->db->load($obj_type,$object_args);
                    }
                }
            #   $v = $ctx->mt->db->get_results("SELECT * FROM mt_ajaxrating_vote WHERE ajaxrating_vote_obj_id=$eid", ARRAY_A);
                $e['total_score'] = $pop_entry[$_fp . 'total_score'];
                $e['avg_score'] = $pop_entry[$_fp . 'avg_score'];
                $e['vote_count'] = $pop_entry[$_fp . 'vote_count'];
            #   $e['votes'] = $v;
                $objects[] = $e;
            }

        $ctx->stash('pop_entries', true);
        $ctx->stash('objects', $objects);
    }
    if (($lastn > count($objects)) || ($lastn == -1)) {
        $lastn = count($objects);
        $ctx->stash('_entries_lastn', $lastn);
    }
    if ($lastn ? ($counter < $lastn) : ($counter < count($objects))) {
        $object = $objects[$counter];
        $obj_type = $ctx->stash('obj_type');
        if ($counter > 0) {
            $last_entry_created_on = $objects[$counter-1][$obj_type . '_created_on'];
        } else {
            $last_entry_created_on = '';
        }
        if ($counter < count($objects)-1) {
            $next_entry_created_on = $objects[$counter+1][$obj_type . '_created_on'];
        } else {
            $next_entry_created_on = '';
        }
        $ctx->stash('DateHeader', !(substr($object[$obj_type . '_created_on'], 0, 8) == substr($last_entry_created_on, 0, 8)));
        $ctx->stash('DateFooter', (substr($object[$obj_type . '_created_on'], 0, 8) != substr($next_entry_created_on, 0, 8)));
        $ctx->stash($obj_type, $object);
        $ctx->stash('obj_type', $obj_type);
        $ctx->stash('current_timestamp', $object[$obj_type . '_created_on']);
        $ctx->stash('current_timestamp_end', null);
        $ctx->stash('modification_timestamp', $object[$obj_type . '_modified_on']);
        $ctx->stash('_entries_counter', $counter + 1);
        $repeat = true;
    } else {
        $ctx->restore($localvars);
        $repeat = false;
    }
    return $content;

}

?>
