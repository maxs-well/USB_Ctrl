# USB_Ctrl
使用Verilog对USB芯片的控制时序示例

环境
=
FPGA：Altera Cyclone IV E EP4CE30F23C8</br>
Software：Quartus II 13.0</br>
USB IC: CY7C68013A</br>
本代码针对 所使用的开发板上的USB芯片 调试，不保证一定可以移植到别的平台上正常使用，仅供参考</br>
USB的传输方式选择了异步传输

文件
=
* `usb_ctrl.v` : CY7C68013A USB芯片的驱动程序，使用verilog语言    
* `usb_top.v`  : 对`usb_ctrl.v`的示例使用程序（example）

`usb_top.v`
==
参数定义
--
* `LOOP_WORK` : 当该参数设为1时，发送的数据将会是从USB芯片接受到的数据，形成一个loopback，write_data输入端口无效
* `AUTO_WORK` : 当该参数设为1时，驱动将会自动完成读取USB数据到向USB写入数据的过程，此参数主要用于测试使用
* `AUTO_RNUM` : 当`AUTO_WORK`为1时，该值有效，该值表示每次读取数据过程的数目，同时rd_wr_num输入端口无效
* `AUTO_WNUM` : 当`AUTO_WORK`为1时，该值有效，该值表示每次写入数据过程的数目，同时rd_wr_num输入端口无效
* `TS_NUM`    : 每次读取过程或者写入数据过程中需要等待的时间长度，时间最好控制在50ns以上

状态机跳转条件
------
* `IDLE`    ：空闲状态，如果不在测试状态（`AUTO_WORK = 0`），会根据rd_wr_en, usb_n_ept_to或usb_n_ful_sx进行状态跳转至`RD_PRE`,`WR`;否则会根据usb_n_ept_to或usb_n_ful_sx进行状态跳转至`RD_PRE`,`WR`，优先进入`RD_PRE`

* `RD_PRE`  ：读取准备状态，拉低usb_sloe, usb_slrd，然后跳转至`RD`

* `RD`      ：读取状态，如果fifo读取已空，会跳转至`RD_BURST`；如果不在测试状态，会根据rd_wr_en，cnt_data进行状态跳转至`RD_OVER`,`RD_BURST`;否则会根据cnt_data进行状态跳转至`RD_BURST`，该过程usb_sloe,usb_slrd,ts_cnt会进行相关操作

* `RD_BURST`：读取结束状态，如果不在测试状态，状态回到`IDLE`状态，否则根据usb_n_ful_sx跳转到`WR`或`IDLE`状态

* `RD_OVER` ：再次读取状态，该状态在测试状态下不会使用。仅当非测试状态并且在`RD`状态下读取完rd_wr_num的数据后rd_wr_en依旧使能读状态时会进入该状态；如果fifo读取已空，会跳转至`RD_BURST`，会根据rd_wr_en，cnt_data进行状态跳转至`RD_OVER`,`RD_BURST`

* `WR`      ：写入状态，如果fifo写入已满，会跳转至`WR_BURST`；如果不在测试状态，会根据rd_wr_en，cnt_data进行状态跳转至`WR_OVER`,`WR_BURST`;否则会根据cnt_data进行状态跳转至`WR_BURST`，该过程usb_sloe,usb_slrd,ts_cnt会进行相关操作

* `WR_BURST`：写入结束状态，状态跳转至`IDLE`状态

* `WR_OVER` ：再次写入状态，该状态在测试状态下不会使用。仅当非测试状态并且在`WR`状态下读取完rd_wr_num的数据后rd_wr_en依旧使能写状态时会进入该状态；如果fifo写入已满，会跳转至`WR_BURST`，会根据rd_wr_en，cnt_data进行状态跳转至`WR_OVER`,`WR_BURST`

内部寄存器状态
--
主要是wr_req(控制inout端口的usb_data的输入输出方向),cnt_data（记录读取或写入数据的数目）,ts_cnt（每次读取或者写入过程前的setup time计数器）在各种状态下的输出操作。

外部信号
--
主要有tra_data（传输数据）,usb_slcs（usb片选信号，低有效），usb_sloe（usb输出有效信号，低有效）,usb_slrd（usb读取信号，低有效），usb_slwr（usb写入信号，低有效），usb_addr（usb的fifo地址），read_data（读取的数据），output_valid（输出数据的有效指示信号），write_ready（写入数据的准备信号）。
