#include <tamtypes.h>
#include <ps2smb.h>
#include <string.h>
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fileio.h>
#include "include/dprintf.h"
#include "include/luaplayer.h"

typedef struct
{                          // size = 1148
	char Server_IP[16];    //IP address of this server
	int Server_Port;       //IP port for use with this server
	char Username[256];    //Username for login to this server (NUL if anonymous)
	char Password[256];    //Password for login to this server (ignore if anonymous)
	int PasswordType;      // PLAINTEXT_PASSWORD or HASHED_PASSWORD or NO_PASSWORD
	u8 PassHash[32];       //Hashed password for this server (unused if anonymous)
	int PassHash_f;        //Flags hashing already performed if non-zero
	int Server_Logon_f;    //Flags successful logon to this server
	char Client_ID[256];   //Unit name of ps2, in SMB traffic with this server
	char Server_ID[256];   //Unit name of this server, as defined for SMB traffic
	char Server_FBID[64];  //Name of this server for display in FileBrowser
} smbServer_t;         //uLE SMB ServerList entry type
smbServer_t smbServer;

int smbLogon_Server(int Index)
{
	int ret;
	smbLogOn_in_t logon;


	if (smbServer.Server_Logon_f == 1) {
		DPRINTF("smbLogon_Server: Request for duplicate logon noted.\n");
		return -1;
	}

	if (smbServer.Username[0] == 0)  //if Username invalid
		strcpy(smbServer.Username, "GUEST");

	if ((smbServer.PasswordType > 0)  //if hashing wanted
	    && (smbServer.PassHash_f == 0)) {
		ret = fileXioDevctl("smb:", SMB_DEVCTL_GETPASSWORDHASHES, (void *)&smbServer.Password, sizeof(smbServer.Password), (void *)&smbServer.PassHash, sizeof(smbServer.PassHash));
		if (ret) {
			DPRINTF("smbLogon_Server: PassHash error %d\n", ret);
			return -1;
		}
		smbServer.PassHash_f = 1;  //PassHash is now valid for future use
	}

	strcpy(logon.serverIP, smbServer.Server_IP);
	logon.serverPort = smbServer.Server_Port;
	strcpy(logon.User, smbServer.Username);
	if (smbServer.PasswordType > 0)  //if hashing wanted
		memcpy((void *)logon.Password, (void *)smbServer.PassHash, sizeof(smbServer.PassHash));
	else
		strcpy(logon.Password, smbServer.Password);
	logon.PasswordType = smbServer.PasswordType;

	ret = fileXioDevctl("smb:", SMB_DEVCTL_LOGON, (void *)&logon, sizeof(logon), NULL, 0);
	if (ret) {
		DPRINTF("smbLogon_Server: Logon Error %d\n", ret);
		return -1;
	}
	smbServer.Server_Logon_f = 1;
	DPRINTF("smbLogon_Server: Logon succeeded!\n");
	return 0;  //Here basic Logon has been achieved
}