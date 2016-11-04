[% FOREACH [1..qty] %]
^XA
^CI28
^CW1,E:HEITI.FNT
^CW2,E:ARIREG.FNT
^CW3,E:ARIBLD.FNT
^PW1248
^FPH
^FWN

^FO50,70
^A1,60,55
^FD[% item.name %]^FS


^FO50,80
^FB830,3,10,R,0
^A1,42
^FD[% item.storage %]^FS

^FO0,150^GB1200,0,1^FS

^FO50,180
^A1,40,40
^FD净含量：[% item.net %]^FS


^FO50,240
^FB830,3,10,L,0
^A1,28,28
^FD经销：上海天天鲜果电子商务有限公司\&地址：上海市浦东新区祖冲之路887弄71-72号楼4楼\&电话：400-720-0770^FS





^FO0,360^GB1200,0,1^FS


^FO50,390
^BY3^BCN,150,Y,N,N
^FD[% item.code %]^FS



^XZ
[% END %]
