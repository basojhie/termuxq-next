// Member invitation and role management is server-only. Never ship the service-role key to the browser.
import { createClient } from "npm:@supabase/supabase-js@2";
const headers = { "Access-Control-Allow-Origin":"*", "Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods":"POST, OPTIONS" };
const respond=(body:Record<string,unknown>,status=200)=>Response.json(body,{status,headers});
const validRole=(role:unknown):role is "admin"|"technician"|"viewer"=>role==="admin"||role==="technician"||role==="viewer";
const validUuid=(value:unknown):value is string=>typeof value==="string"&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);

Deno.serve(async(request:Request)=>{
 if(request.method==="OPTIONS")return new Response("ok",{headers});
 if(request.method!=="POST")return respond({error:"Method not allowed"},405);
 const bearer=request.headers.get("Authorization");
 if(!bearer?.startsWith("Bearer "))return respond({error:"Login diperlukan."},401);
 const url=Deno.env.get("SUPABASE_URL"),anonKey=Deno.env.get("SUPABASE_ANON_KEY")||Deno.env.get("SUPABASE_PUBLISHABLE_KEY"),serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!anonKey||!serviceKey)return respond({error:"Secret server belum lengkap."},503);
 try{
  const authClient=createClient(url,anonKey,{auth:{persistSession:false,autoRefreshToken:false},global:{headers:{Authorization:bearer}}});
  const authResult=await authClient.auth.getUser(),caller=authResult.data.user;
  if(authResult.error||!caller)return respond({error:"Sesi tidak valid."},401);
  const body=await request.json(),orgId=body?.organizationId,action=body?.action;
  if(!validUuid(orgId))return respond({error:"Workspace ID tidak valid."},400);
  const admin=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const own=await admin.from("termuxq_organization_members").select("role").eq("organization_id",orgId).eq("user_id",caller.id).maybeSingle();
  if(own.error)return respond({error:"Peran workspace tidak dapat diverifikasi."},503);
  if(!own.data||own.data.role!=="admin")return respond({error:"Hanya admin workspace yang dapat mengubah anggota."},403);

  if(action==="invite"){
   const email=typeof body.email==="string"?body.email.trim().toLowerCase():"",role=body.role;
   if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>254)return respond({error:"Email tidak valid."},400);
   if(!validRole(role))return respond({error:"Role harus admin, technician, atau viewer."},400);
   const roster=await admin.from("termuxq_organization_members").select("user_id,email").eq("organization_id",orgId);
   if(roster.error)return respond({error:"Daftar anggota tidak dapat dibaca."},503);
   if((roster.data||[]).some((m:{email?:string})=>(m.email||"").toLowerCase()===email))return respond({error:"Email tersebut sudah menjadi anggota workspace."},409);
   let target:{id:string;email?:string|null}|null=null;
   for(let page=1;page<=20&&!target;page++){
    const listed=await admin.auth.admin.listUsers({page,perPage:1000});
    if(listed.error)return respond({error:"Akun email tujuan tidak dapat dicari."},503);
    target=(listed.data.users.find(u=>(u.email||"").toLowerCase()===email) as {id:string;email?:string|null}|undefined)||null;
    if(listed.data.users.length<1000)break;
   }
   let invited=false;
   if(!target){
    const invite=await admin.auth.admin.inviteUserByEmail(email,{data:{termuxq_invited_to:orgId}});
    if(invite.error||!invite.data.user)return respond({error:"Undangan email gagal. Periksa SMTP dan Auth Supabase."},502);
    target={id:invite.data.user.id,email:invite.data.user.email};invited=true;
   }
   const inserted=await admin.from("termuxq_organization_members").insert({organization_id:orgId,user_id:target.id,email,role});
   if(inserted.error)return respond({error:"Akun ditemukan, tetapi penambahan anggota gagal. Periksa duplikasi atau coba ulang."},409);
   return respond({ok:true,invited,email,role});
  }

  const targetId=body?.userId;
  if(!validUuid(targetId))return respond({error:"ID anggota tidak valid."},400);
  if(targetId===caller.id&&action==="remove")return respond({error:"Admin tidak dapat menghapus dirinya sendiri dari workspace."},409);
  const roster=await admin.from("termuxq_organization_members").select("user_id,role").eq("organization_id",orgId);
  if(roster.error)return respond({error:"Daftar anggota tidak dapat dibaca."},503);
  const target=(roster.data||[]).find((m:{user_id:string})=>m.user_id===targetId);
  if(!target)return respond({error:"Anggota tidak ditemukan di workspace ini."},404);
  const admins=(roster.data||[]).filter((m:{role:string})=>m.role==="admin").length;
  if(action==="set_role"){
   const role=body.role;
   if(!validRole(role))return respond({error:"Role harus admin, technician, atau viewer."},400);
   if(target.role==="admin"&&role!=="admin"&&admins<=1)return respond({error:"Workspace harus memiliki setidaknya satu admin."},409);
   const result=await admin.from("termuxq_organization_members").update({role}).eq("organization_id",orgId).eq("user_id",targetId);
   if(result.error)return respond({error:"Perubahan role gagal."},503);
   return respond({ok:true,role});
  }
  if(action==="remove"){
   if(target.role==="admin"&&admins<=1)return respond({error:"Workspace harus memiliki setidaknya satu admin."},409);
   const result=await admin.from("termuxq_organization_members").delete().eq("organization_id",orgId).eq("user_id",targetId);
   if(result.error)return respond({error:"Penghapusan anggota gagal."},503);
   return respond({ok:true});
  }
  return respond({error:"Action tidak dikenal."},400);
 }catch(_error){return respond({error:"Permintaan pengelolaan anggota tidak dapat diproses."},400)}
});
