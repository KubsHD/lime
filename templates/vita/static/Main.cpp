#include <stdio.h>

extern "C"
{
	#include <psp2/kernel/modulemgr.h>
	#include <psp2/kernel/processmgr.h>
	#include <psp2/kernel/clib.h>
	#include <gpu_es4/psp2_pvr_hint.h>
}


extern "C" const char *hxRunLibrary ();
extern "C" void hxcpp_set_top_of_stack ();

extern "C" int zlib_register_prims ();
extern "C" int lime_cairo_register_prims ();
extern "C" int lime_openal_register_prims ();
::foreach ndlls::::if (registerStatics)::
extern "C" int ::nameSafe::_register_prims ();::end::::end::



extern "C" int main(int argc, char *argv[]) {
	sceClibPrintf("Haxe init");

	sceKernelLoadStartModule("vs0:sys/external/libfios2.suprx", 0, NULL, 0, NULL, NULL);
	sceKernelLoadStartModule("vs0:sys/external/libc.suprx", 0, NULL, 0, NULL, NULL);
	sceKernelLoadStartModule("app0:sce_module/libgpu_es4_ext.suprx", 0, NULL, 0, NULL, NULL);
  	sceKernelLoadStartModule("app0:sce_module/libIMGEGL.suprx", 0, NULL, 0, NULL, NULL);
	sceClibPrintf("Module init OK\n");

	PVRSRV_PSP2_APPHINT hint;
  	PVRSRVInitializeAppHint(&hint);
  	PVRSRVCreateVirtualAppHint(&hint);
	sceClibPrintf("PVE_PSP2 init OK.\n");

	hxcpp_set_top_of_stack ();

	zlib_register_prims ();
	lime_cairo_register_prims ();
	lime_openal_register_prims ();
	::foreach ndlls::::if (registerStatics)::
	::nameSafe::_register_prims ();::end::::end::

	const char *err = NULL;
 	err = hxRunLibrary ();

	if (err) {

		printf("Error: %s\n", err);
		return -1;

	}

	return 0;

}